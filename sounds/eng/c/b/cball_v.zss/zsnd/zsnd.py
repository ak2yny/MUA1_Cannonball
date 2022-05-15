from collections import namedtuple
from struct import pack, unpack, calcsize
import json, wave, struct
from wave import Error, WAVE_FORMAT_PCM
from operator import attrgetter, itemgetter
from pathlib import Path
from argparse import ArgumentParser
import glob, math

Header = namedtuple('Header', [
    'size',
    'header_size',
    'sound_count',
    'sound_hashes_offset',
    'sounds_offset',
    'sample_count',
    'sample_hashes_offset',
    'samples_offset',
    'sample_file_count',
    'sample_file_hashes_offset',
    'sample_files_offset',
    'phrase_count',
    'phrase_hashes_offset',
    'phrases_offset',
    'track_def_count',
    'track_def_hashes_offset',
    'track_defs_offset',
    'reserved_count',
    'reserved_hashes_offset',
    'reserved_offset',
    'keymap_count',
    'keymap_hashes_offset',
    'keymaps_offset'
])

header_fmt = '< 23I'
header_big_fmt = '> 23I'
header_size = calcsize(header_fmt)

Hash = namedtuple('Hash', [
    'value',
    'index'
])

hash_fmt = '< 2I'
hash_big_fmt = '> 2I'
hash_size = calcsize(hash_fmt)

Sound = namedtuple('Sound', [
    'sample_index',
    'short2',
    'byte4',
    'flags',
    'byte9',
    'byte11',
    'byte19',
    'byte20',
    'byte21'
])

sound_fmt = '< 2H B x B 2x B x B 7x 3B 2x'
sound_big_fmt = '> 2H B x B 2x B x B 7x 3B 2x'
sound_size = calcsize(sound_fmt)

Sample = namedtuple('Sample', [
    'file_index',
    'flags',
    'rate'
])

sample_pc_fmt = '< 2H I 16x'
sample_gamecube_fmt = '> 2H I 16x'
sample_xbox_fmt = '< 2H I 20x'
sample_xenon_fmt = '> 2H I 28x'
sample_pc_gamecube_size = calcsize(sample_pc_fmt)
sample_xbox_size = calcsize(sample_xbox_fmt)
sample_xenon_size = calcsize(sample_xenon_fmt)

SamplePSX = namedtuple('SamplePSX', [
    'file_index',
    'pitch',
    'flags'
])

sample_ps2_fmt = '< 3H 10x'
sample_ps3_fmt = '> 3H 10x'
sample_psx_size = calcsize(sample_ps2_fmt)

SampleFile = namedtuple('SampleFile', [
    'offset',
    'size',
    'format',
    'name'
])

sample_file_pc_fmt = '< 3I 64s'
sample_file_xbox_fmt = '< 3I 8x 64s'
sample_file_xenon_fmt = '> 3I 8x 64s'
sample_file_pc_size = calcsize(sample_file_pc_fmt)
sample_file_xbox_size = calcsize(sample_file_xbox_fmt)

SampleFilePSX = namedtuple('SampleFilePSX', [
    'offset',
    'size'
])

sample_file_ps2_fmt = '< 2I'
sample_file_ps3_fmt = '> 2I'
sample_file_psx_size = calcsize(sample_file_ps2_fmt)

SampleFileGameCube = namedtuple('SampleFileGameCube', [
    'offset',
    'size',
    'type'
])

sample_file_gamecube_fmt = '> 2I 4s'
sample_file_gamecube_size = calcsize(sample_file_gamecube_fmt)

vag_header_fmt = '> 4s I 4x 2I 12x 16s'
vag_header_size = calcsize(vag_header_fmt)

'''
xbadpcm_header_fmt = '< 4s I 4s 4s I 2H 2I 4H 4s I'
xbadpcm_header_size = calcsize(xbadpcm_header_fmt)

riff_header_fmt = '< 4s I 4s'
riff_format_fmt = '< 4s I h H 2I 2H'
riff_data_fmt = '< 4s I'
riff_header_size = calcsize(riff_header_fmt)
riff_format_size = calcsize(riff_format_fmt)
riff_data_size = calcsize(riff_data_fmt)
'''

def pjw_hash(key: str) -> int:
    hash = 0
    test = 0
    for c in key:
        hash = (hash << 4) + ord(c)
        test = hash & 0xF0000000
        if test != 0:
            hash = ((hash ^ (test >> 24)) & (~0xF0000000))
    return (hash & 0x7FFFFFFF)

def get_header_format(platform: str) -> str:
    return header_big_fmt if (platform == 'GCUB' or platform == 'PS3' or platform == 'XENO') else header_fmt

def get_hash_format(platform: str) -> str:
    return hash_big_fmt if (platform == 'GCUB' or platform == 'PS3' or platform == 'XENO') else hash_fmt

def get_sound_format(platform: str) -> str:
    return sound_big_fmt if (platform == 'GCUB' or platform == 'PS3' or platform == 'XENO') else sound_fmt

def get_sample_format(platform: str) -> str:
    sample_format = {
        'PC': sample_pc_fmt,
        'PS2': sample_ps2_fmt,
        'XBOX': sample_xbox_fmt,
        'GCUB': sample_gamecube_fmt,
        'PS3': sample_ps3_fmt,
        'XENO': sample_xenon_fmt
    }
    return sample_format.get(platform)

def get_sample_file_format(platform: str) -> str:
    sample_file_format = {
        'PC': sample_file_pc_fmt,
        'PS2': sample_file_ps2_fmt,
        'XBOX': sample_file_xbox_fmt,
        'GCUB': sample_file_gamecube_fmt,
        'PS3': sample_file_ps3_fmt,
        'XENO': sample_file_xenon_fmt
    }
    return sample_file_format.get(platform)

def get_sample_size(platform: str) -> int:
    if platform == 'PC' or platform == 'GCUB':
        return sample_pc_gamecube_size
    elif platform == 'PS2' or platform == 'PS3':
        return sample_psx_size
    elif platform == 'XBOX':
        return sample_xbox_size
    elif platform == 'XENO':
        return sample_xenon_size
    return -1

def get_sample_file_size(platform: str) -> int:
    if platform == 'PC':
        return sample_file_pc_size
    elif platform == 'GCUB':
        return sample_file_gamecube_size
    elif platform == 'PS2' or platform == 'PS3':
        return sample_file_psx_size
    elif platform == 'XBOX' or platform == 'XENO':
        return sample_file_xbox_size
    return -1

hash_strings = {}

def hash2str(sound_hash: int):
    global hash_strings

    key = str(sound_hash)

    if not hash_strings:
        with open('hashes.json', 'r') as hashes_file:
            hash_strings = json.load(hashes_file)
    return hash_strings[key] if (key in hash_strings) else sound_hash
    
def pitch2rate(pitch: int) -> int:
    rate = pitch * 44100 / 4096
    return int(rate if rate.is_integer() else round(rate, -1))

def rate2pitch(rate: int) -> int:
    return round(rate * 4096 / 44100)

'''
WAVE_FORMAT_XBADPCM = 0x0069

def _read_fmt_chunk(self, chunk):
    try:
        wFormatTag, self._nchannels, self._framerate, dwAvgBytesPerSec, wBlockAlign = struct.unpack_from('<HHLLH', chunk.read(14))
    except struct.error:
        raise EOFError from None
    if not self._nchannels:
        raise Error('bad # of channels')
    if wFormatTag == WAVE_FORMAT_PCM:
        try:
            sampwidth = struct.unpack_from('<H', chunk.read(2))[0]
        except struct.error:
            raise EOFError from None
        self._sampwidth = (sampwidth + 7) // 8
        if not self._sampwidth:
            raise Error('bad sample width')
        self._framesize = self._nchannels * self._sampwidth
        self._comptype = 'NONE'
        self._compname = 'not compressed'
    elif wFormatTag == WAVE_FORMAT_XBADPCM:
        self._sampwidth = 1
        self._framesize = 1
        self._comptype = 'XBOX_ADPCM'
        self._compname = 'XBOX ADPCM'
    else:
        raise Error('unknown format: %r' % (wFormatTag,))

def setcomptype(self, comptype, compname):
    if self._datawritten:
        raise Error('cannot change parameters after starting to write')
    if comptype not in ('NONE', 'XBOX_ADPCM'):
        raise Error('unsupported compression type')
    self._comptype = comptype
    self._compname = compname

def _write_header(self, initlength):
    assert not self._headerwritten
    self._file.write(b'RIFF')
    if not self._nframes:
        self._nframes = initlength // (self._nchannels * self._sampwidth)
    try:
        self._form_length_pos = self._file.tell()
    except (AttributeError, OSError):
        self._form_length_pos = None
    if self._comptype == 'XBOX_ADPCM':
        wBlockAlign = 36 * self._nchannels
        self._datalength = self._nframes
        self._file.write(struct.pack('<L4s4sLHHLLHHHH4s',
            36 + self._datalength, b'WAVE', b'fmt ', 20,
            WAVE_FORMAT_XBADPCM, self._nchannels, self._framerate,
            self._framerate * wBlockAlign >> 6,
            wBlockAlign,
            4, 2, 64, b'data'))
    else:
        self._datalength = self._nframes * self._nchannels * self._sampwidth
        self._file.write(struct.pack('<L4s4sLHHLLHH4s',
            36 + self._datalength, b'WAVE', b'fmt ', 16,
            WAVE_FORMAT_PCM, self._nchannels, self._framerate,
            self._nchannels * self._framerate * self._sampwidth,
            self._nchannels * self._sampwidth,
            self._sampwidth * 8, b'data'))
    if self._form_length_pos is not None:
        self._data_length_pos = self._file.tell()
    self._file.write(struct.pack('<L', self._datalength))
    self._headerwritten = True

wave.Wave_read._read_fmt_chunk = _read_fmt_chunk
wave.Wave_write.setcomptype = setcomptype
wave.Wave_write._write_header = _write_header
'''

def decompile(input: Path, output: Path):
    with input.open(mode='rb') as zsnd_file:
        if (zsnd_file.read(4) != b'ZSND'):
            raise ValueError('Invalid magic number')

        platform = zsnd_file.read(4).decode('utf-8').rstrip()

        if platform != 'PC' and platform != 'PS2' and platform != 'XBOX' and platform != 'GCUB' and platform != 'PS3' and platform != 'XENO':
            raise ValueError(f'Platform {platform} is not supported')

        header = Header._make(unpack(get_header_format(platform), zsnd_file.read(header_size)))
        
        if header.sound_count <= 0 or header.sample_count <= 0 or header.sample_file_count <= 0:
            return
        
        data = {}
        sounds = []
        samples = []
        sound_hashes = []

        data['platform'] = platform
        data['sounds'] = sounds
        data['samples'] = samples

        zsnd_file.seek(header.sound_hashes_offset)

        for sound_index in range(header.sound_count):
            sound_hashes.append(unpack(get_hash_format(platform), zsnd_file.read(hash_size)))

        sound_hashes.sort(key=itemgetter(1))
        zsnd_file.seek(header.sounds_offset)

        for hash_value, index in sound_hashes:
            sound = unpack(get_sound_format(platform), zsnd_file.read(sound_size))

            sounds.append({
                'hash': hash2str(hash_value),
                'sample_index': sound[0],
                'flags': sound[3]
            })

        for i in range(header.sample_count):
            sample_size = get_sample_size(platform)
            zsnd_file.seek(header.samples_offset + i * sample_size)
            sample = unpack(get_sample_format(platform), zsnd_file.read(sample_size))

            sample_file_size = get_sample_file_size(platform)
            zsnd_file.seek(header.sample_files_offset + sample[0] * sample_file_size)
            sample_file = unpack(get_sample_file_format(platform), zsnd_file.read(sample_file_size))

            if (platform == 'PC' or platform == 'XBOX' or platform == 'XENO'):
                sound_name = sample_file[3].decode('utf-8').rstrip('\u0000')
            else:
                suffix = '.dsp' if (platform == 'GCUB') else '.vag'
                sound_name = f'{i}{suffix}'

            sound_path = output.parent / output.stem / sound_name
            sound_path.parent.mkdir(parents=True, exist_ok=True)
            sound_name = sound_path.stem
            
            counter = 1

            while sound_path.exists():
                sound_path = sound_path.with_stem(f'{sound_name}_{counter}')#sound_path.parent / f'{sound_name}_{counter}{sound_path.suffix}'
                counter += 1

            is_psx = platform == 'PS2' or platform == 'PS3'

            sample_data = {
                'file': str(sound_path),
                'format': sample_file[2] if (platform == 'PC' or platform == 'XBOX' or platform == 'XENO') else -1,
                'sample_rate': pitch2rate(sample[1]) if (is_psx) else sample[2],
                'flags': sample[2] if (is_psx) else sample[1]
            }
    
            flags = sample_data['flags']
            #channels = 1

            #if (flags & 0b0010 != 0):
            #    channels = 4 if (flags & 0b00100000 != 0) else 2

            if (sample_data['format'] < 0): sample_data.pop('format')
            if (sample_data['flags'] <= 0): sample_data.pop('flags')

            samples.append(sample_data)

            zsnd_file.seek(sample_file[0])

            #TODO:if platform == 'XBOX': or platform == "PC" 
                #with wave.open(sound_path.with_suffix('.wav'), 'w') as wav_file:
                #    wav_file.setnchannels(channels)
                #    wav_file.setsampwidth(1)
                #    wav_file.setframerate(sample_data['sample_rate'])
                #    wav_file.setcomptype('XBOX_ADPCM', 'XBOX ADPCM')
                #    wav_file.writeframes(zsnd_file.read(sample_file[1]))
            #else:      
            with sound_path.open(mode='wb') as sound_file:
                size = sample_file[1]
                sample_rate = sample_data['sample_rate']

                if is_psx and flags == 0:
                    sound_file.write(pack(vag_header_fmt, b'VAGp', 0x20, size, sample_rate, sound_path.stem.encode('utf-8')))
                #elif (platform == 'XBOX'):
                    #samples_per_sec = sample_rate
                    #block_align = 36 * 1 #TODO: Channels count
                    #avg_bytes_per_sec = samples_per_sec * block_align >> 6
                    #sound_file.write(pack(xbadpcm_header_fmt, b'RIFF', size + 40, b'WAVE', b'fmt ', 20, 0x69, 1, samples_per_sec, avg_bytes_per_sec, block_align, 4, 2, 64, b'data', size))
                
                sound_file.write(zsnd_file.read(size))

        with output.open(mode='w') as json_file:
            json.dump(data, json_file, indent=4)

def multipleOf(n, x):
    return math.ceil(n / x) * x

def compile(input: Path, output: Path):
    with input.open(mode='r') as json_file:
        data = json.load(json_file)
        platform = data['platform']
        is_psx = platform == 'PS2' or platform == 'PS3'

        json_sounds = data['sounds']
        json_samples = data['samples']
        sound_count = len(json_sounds)
        sample_count = len(json_samples)
        sound_hashes_offset = 8 + header_size
        sounds_offset = sound_hashes_offset + sound_count * hash_size
        sample_hashes_offset = sounds_offset + sound_count * sound_size
        samples_offset = sample_hashes_offset + sample_count * hash_size
        sample_file_hashes_offset = samples_offset + sample_count * get_sample_size(platform)
        sample_files_offset = sample_file_hashes_offset + sample_count * hash_size
        files_data_offset = sample_files_offset + sample_count * get_sample_file_size(platform)
        
        sound_hashes = []
        sounds = []
        sample_hashes = []
        samples = []
        sample_file_hashes = []
        sample_files = []
        files_data = bytearray()

        if platform != 'GCUB':
            padding = multipleOf(files_data_offset, 16) - files_data_offset
            files_data_offset += padding
            files_data += pack(f'{padding}x')

        for sample_index, sound in enumerate(json_sounds):
            sound_hash = sound['hash']
            byte_11 = 15 if (is_psx) else 127
            byte_19_20_21 = 32 if (platform == 'PS3') else 0

            sound_hashes.append((pjw_hash(sound_hash.upper()) if (isinstance(sound_hash, str)) else sound_hash, sample_index))
            sounds.append((sound['sample_index'], 4096, 127, sound['flags'], 127, byte_11, byte_19_20_21, byte_19_20_21, byte_19_20_21))

        file_data_offset = files_data_offset

        for sample_index, sample in enumerate(json_samples):
            zsnd_name = input.stem.upper()
            sample_file_path = Path(sample['file'])
            sample_file_name = sample_file_path.stem.upper()
            sample_rate = sample['sample_rate']
            flags = sample['flags'] if ('flags' in sample) else 0

            sample_hashes.append((pjw_hash(f'CHARS3/7R/{zsnd_name}/{sample_file_name}'), sample_index))
            sample_file_hashes.append((pjw_hash(f'FILE/{zsnd_name}/{sample_file_name}'), sample_index))

            if is_psx:
                samples.append((sample_index, rate2pitch(sample_rate), flags))
            else:
                samples.append((sample_index, flags, sample_rate))

            with sample_file_path.open(mode='rb') as sample_file:
                if is_psx and flags == 0:
                    sample_file.seek(vag_header_size)
                file_data = sample_file.read()
                file_size = len(file_data)
                padding = 0

                if sample_index != (sample_count - 1):
                    padding = multipleOf(file_size, 4 if (platform == 'GCUB') else 16) - file_size

                files_data += file_data
                
                if padding > 0:
                    files_data += pack(f'{padding}x')

                if is_psx:
                    sample_files.append((file_data_offset, file_size))
                elif platform == 'GCUB':
                    sample_files.append((file_data_offset, file_size, b'DSP '))
                else:
                    sample_files.append((file_data_offset, file_size, sample['format'], sample_file_path.name.encode('utf-8')))

                file_data_offset += (file_size + padding)

        sound_hashes.sort(key=itemgetter(0))
        sample_hashes.sort(key=itemgetter(0))
        sample_file_hashes.sort(key=itemgetter(0))

        with output.open(mode='wb') as zsnd_file:
            zsnd_file.write(b'ZSND')
            zsnd_file.write(platform.ljust(4).encode('utf-8'))
            zsnd_file.write(pack(get_header_format(platform), file_data_offset, files_data_offset, 
                sound_count, sound_hashes_offset, sounds_offset, 
                sample_count, sample_hashes_offset, samples_offset, 
                sample_count, sample_file_hashes_offset, sample_files_offset, 
                0, files_data_offset, files_data_offset, 
                0, files_data_offset, files_data_offset, 
                0, files_data_offset, files_data_offset, 
                0, files_data_offset, files_data_offset))

            for sound_hash in sound_hashes:
                zsnd_file.write(pack(get_hash_format(platform), *sound_hash))

            for sound in sounds:
                zsnd_file.write(pack(get_sound_format(platform), *sound))

            for sample_hash in sample_hashes:
                zsnd_file.write(pack(get_hash_format(platform), *sample_hash))

            for sample in samples:
                zsnd_file.write(pack(get_sample_format(platform), *sample))

            for sample_file_hash in sample_file_hashes:
                zsnd_file.write(pack(get_hash_format(platform), *sample_file_hash))

            for sample_file in sample_files:
                zsnd_file.write(pack(get_sample_file_format(platform), *sample_file))
            
            zsnd_file.write(files_data)

def main():
    parser = ArgumentParser()
    parser.add_argument('-d', '--decompile', action='store_true', help='decompile input ZSND file to JSON')
    parser.add_argument('input', help='input file (supports glob)')
    parser.add_argument('output', help='output file (wildcards will be replaced by input file name)')
    args = parser.parse_args()
    input_files = glob.glob(args.input, recursive=True)

    if not input_files:
        raise ValueError('No files found')
        #raise FileNotFoundError(errno.ENOENT, os.strerror(errno.ENOENT), Path(args.input).name)

    for input_file in input_files:
        input_file = Path(input_file)
        output_file = Path(args.output.replace('*', input_file.stem))

        if args.decompile:
            decompile(input_file, output_file)
        else:
            compile(input_file, output_file)

if __name__ == '__main__':
    main()