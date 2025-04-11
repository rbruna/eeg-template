function header = mybdf_read_header_old ( filename )

% Based on specifications in:
% * https://www.edfplus.info/specs/edf.html
% * https://www.edfplus.info/specs/edfplus.html
%
% Based on functions:
% * read_biosemi_bdf by Robert Oostenveld.
% * openbdf (from EEGLAB).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read the header, this code is from EEGLAB's openbdf
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


try
    fid = fopen ( filename, 'r', 'ieee-le' );
catch err
    fprintf(2,['Error LOADEDF: File ' filename ' not found\n']);
    return
end


EDF.FileName = filename;


H1=char(fread( fid ,256,'char')');     %
EDF.VERSION=H1(1:8);                          % 8 Byte  Versionsnummer
%if 0 fprintf(2,'LOADEDF: WARNING  Version EDF Format %i',ver); end;
EDF.PID = deblank(H1(9:88));                  % 80 Byte local patient identification
EDF.RID = deblank(H1(89:168));                % 80 Byte local recording identification
%EDF.H.StartDate = H1(169:176);               % 8 Byte
%EDF.H.StartTime = H1(177:184);               % 8 Byte
EDF.T0=[str2num(H1(168+[7 8])) str2num(H1(168+[4 5])) str2num(H1(168+[1 2])) str2num(H1(168+[9 10])) str2num(H1(168+[12 13])) str2num(H1(168+[15 16])) ];

% Y2K compatibility until year 2090
if EDF.VERSION(1)=='0'
    if EDF.T0(1) < 91
        EDF.T0(1)=2000+EDF.T0(1);
    else
        EDF.T0(1)=1900+EDF.T0(1);
    end
else
    % in a future version, this is hopefully not needed
end

EDF.HeadLen = str2num(H1(185:192));  % 8 Byte  Length of Header
% reserved = H1(193:236);            % 44 Byte
EDF.NRec = str2num(H1(237:244));     % 8 Byte  # of data records
EDF.Dur = str2num(H1(245:252));      % 8 Byte  # duration of data record in sec
EDF.NS = str2num(H1(253:256));       % 8 Byte  # of signals

EDF.Label = char(fread( fid ,[16,EDF.NS],'char')');
EDF.Transducer = char(fread( fid ,[80,EDF.NS],'char')');
EDF.PhysDim = char(fread( fid ,[8,EDF.NS],'char')');

EDF.PhysMin= str2num(char(fread( fid ,[8,EDF.NS],'char')'));
EDF.PhysMax= str2num(char(fread( fid ,[8,EDF.NS],'char')'));
EDF.DigMin = str2num(char(fread( fid ,[8,EDF.NS],'char')'));
EDF.DigMax = str2num(char(fread( fid ,[8,EDF.NS],'char')'));

% check validity of DigMin and DigMax
if (length(EDF.DigMin) ~= EDF.NS)
    fprintf(2,'Warning OPENEDF: Failing Digital Minimum\n');
    EDF.DigMin = -(2^15)*ones(EDF.NS,1);
end
if (length(EDF.DigMax) ~= EDF.NS)
    fprintf(2,'Warning OPENEDF: Failing Digital Maximum\n');
    EDF.DigMax = (2^15-1)*ones(EDF.NS,1);
end
if (any(EDF.DigMin >= EDF.DigMax))
    fprintf(2,'Warning OPENEDF: Digital Minimum larger than Maximum\n');
end
% check validity of PhysMin and PhysMax
if (length(EDF.PhysMin) ~= EDF.NS)
    fprintf(2,'Warning OPENEDF: Failing Physical Minimum\n');
    EDF.PhysMin = EDF.DigMin;
end
if (length(EDF.PhysMax) ~= EDF.NS)
    fprintf(2,'Warning OPENEDF: Failing Physical Maximum\n');
    EDF.PhysMax = EDF.DigMax;
end
if (any(EDF.PhysMin >= EDF.PhysMax))
    fprintf(2,'Warning OPENEDF: Physical Minimum larger than Maximum\n');
    EDF.PhysMin = EDF.DigMin;
    EDF.PhysMax = EDF.DigMax;
end
EDF.PreFilt= char(fread( fid ,[80,EDF.NS],'char')');   %
tmp = fread( fid ,[8,EDF.NS],'char')'; %   samples per data record
EDF.SPR = str2num(char(tmp));               % samples per data record

fseek( fid ,32*EDF.NS,0);

EDF.Cal = (EDF.PhysMax-EDF.PhysMin)./(EDF.DigMax-EDF.DigMin);
EDF.Off = EDF.PhysMin - EDF.Cal .* EDF.DigMin;
tmp = find(EDF.Cal < 0);
EDF.Cal(tmp) = ones(size(tmp));
EDF.Off(tmp) = zeros(size(tmp));

% the following adresses https://github.com/fieldtrip/fieldtrip/pull/395
tmp = find(strcmpi(cellstr(EDF.Label), 'STATUS'));
if EDF.Cal(tmp)~=1
    timeout = 60*15; % do not show it for the next 15 minutes
    ft_warning('FieldTrip:BDFCalibration', 'calibration for status channel appears incorrect, setting it to 1', timeout);
    EDF.Cal(tmp) = 1;
end
if EDF.Off(tmp)~=0
    timeout = 60*15; % do not show it for the next 15 minutes
    ft_warning('FieldTrip:BDFOffset', 'offset for status channel appears incorrect, setting it to 0', timeout);
    EDF.Off(tmp) = 0;
end

EDF.Calib=[EDF.Off';(diag(EDF.Cal))];

EDF.SampleRate = EDF.SPR / EDF.Dur;

fpos = ftell( fid );
if EDF.NRec == -1                            % unknown record size, determine correct NRec
    fseek( fid , 0, 'eof');
    endpos = ftell( fid );
    EDF.NRec = floor((endpos - fpos) / (sum(EDF.SPR) * 2));
    fseek( fid , fpos, 'bof');
    H1(237:244)=sprintf('%-8i',EDF.NRec);      % write number of records
end

EDF.Chan_Select=(EDF.SPR==max(EDF.SPR));
for k=1:EDF.NS
    if EDF.Chan_Select(k)
        EDF.ChanTyp(k)='N';
    else
        EDF.ChanTyp(k)=' ';
    end
    if contains(upper(EDF.Label(k,:)),'ECG')
        EDF.ChanTyp(k)='C';
    elseif contains(upper(EDF.Label(k,:)),'EKG')
        EDF.ChanTyp(k)='C';
    elseif contains(upper(EDF.Label(k,:)),'EEG')
        EDF.ChanTyp(k)='E';
    elseif contains(upper(EDF.Label(k,:)),'EOG')
        EDF.ChanTyp(k)='O';
    elseif contains(upper(EDF.Label(k,:)),'EMG')
        EDF.ChanTyp(k)='M';
    end
end

EDF.AS.spb = sum(EDF.SPR);    % Samples per Block

% close the file
fclose( fid );

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% convert the header to Fieldtrip-style
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if any(EDF.SampleRate~=EDF.SampleRate(1))
    ft_error('channels with different sampling rate not supported');
end

header.Fs          = EDF.SampleRate(1);
header.nChans      = EDF.NS;
header.label       = cellstr(EDF.Label);
% it is continuous data, therefore append all records in one trial
header.nTrials     = 1;
header.nSamples    = round ( EDF.NRec * EDF.Dur * EDF.SampleRate (1) );
header.nSamplesPre = 0;
header.orig        = EDF;
