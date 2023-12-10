class Mystic::Note
  getter letter : String
  getter accidental : String
  getter octave : Int32

  PITCHES     = ["C", "D", "E", "F", "G", "A", "B"]
  ALL_PITCHES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

  LETTER_PITCH_CLASSES = {
    "C": 0,
    "D": 2,
    "E": 4,
    "F": 5,
    "G": 7,
    "A": 9,
    "B": 11,
  }

  # Coordinates assume starting from C4
  BASE_OCTAVE  = 4
  PITCH_COORDS = {
    C: Coords.new(0, 0),
    D: Coords.new(-1, 2),
    E: Coords.new(-2, 4),
    F: Coords.new(1, -1),
    G: Coords.new(0, 1),
    A: Coords.new(-1, 3),
    B: Coords.new(-2, 5),
  }

  NAME_PATTERN = "(?<letter>[abcdefgABCDEFG])(?<accidental>[b♭𝄫]+|[#♯x𝄪]*)"

  protected def initialize(@letter, @accidental, @octave)
    @letter = @letter.upcase

    # Normalize accidentals to a standard format
    accidental_offset = Util.accidental_offset(@accidental)
    @accidental = Util.normalize_accidental(accidental_offset)
  end

  def initialize(s : String)
    pattern = "^#{NAME_PATTERN}(?<octave>\\d+)?$"
    match = Regex.new(pattern).match(s)

    raise Error.new("Invalid note name: #{s}") unless match

    letter = match["letter"].upcase
    accidental = match["accidental"]
    octave = match["octave"]?.try(&.to_i) || BASE_OCTAVE
    initialize(letter, accidental, octave)
  end

  def self.from_midi(i : Int32)
    octave = i.tdiv(12) - 1
    pitch_class = i % 12

    Note.new("#{ALL_PITCHES[pitch_class]}#{octave}")
  end

  def self.from_coords(coords : Coords)
    fifths, value = coords.fifths, coords.value

    letter = PITCHES[value % 7]

    octave_offset = value // 7
    octave = BASE_OCTAVE + octave_offset

    use_sharps = coords.fifths.positive?
    accidental_offset = begin
      if use_sharps
        # the 6th ascending fifth (F#) begins the first sharp alteration
        (fifths.abs + 1).tdiv(7)
      else
        # the 2th descending fifth (Bb) begins the first flat alteration
        -1 * (fifths.abs + 5).tdiv(7)
      end
    end

    accidental = Util.normalize_accidental(accidental_offset)

    Note.new(letter, accidental, octave)
  end

  # Returns `Coords` representation
  def coords
    octave_offset = Coords.new(octave - BASE_OCTAVE, 0)

    base_coords = PITCH_COORDS[letter]
    base_coords + (Interval::SHARP_COORDS * accidental_offset) + octave_offset
  end

  def name
    "#{letter}#{accidental}"
  end

  def chroma
    (LETTER_PITCH_CLASSES[letter] + accidental_offset) % 12
  end

  def midi
    (12 * (octave + 1)) + chroma
  end

  def frequency(tuning = 440.0)
    tuning * Math.exp2((midi - 69) / 12)
  end

  def accidental_offset
    Util.accidental_offset(accidental)
  end

  def +(interval : Interval)
    Note.from_coords(coords + interval.coords)
  end

  def -(interval : Interval)
    Note.from_coords(coords - interval.coords)
  end

  def -(other : Note)
    Interval.from_coords(coords - other.coords)
  end

  # Note: this compares notes as ordered on a staff rather than by pitch.
  # For example, a Cx4 < Db4 even though Cx4 sounds higher.
  def <=>(other : Note)
    return octave.<=>(other.octave) if octave != other.octave

    return LETTER_PITCH_CLASSES[letter].<=>(LETTER_PITCH_CLASSES[other.letter]) if letter != other.letter

    accidental_offset.<=>(other.accidental_offset)
  end

  def <(other : Note)
    self.<=>(other) == -1
  end

  def >(other : Note)
    self.<=>(other) == 1
  end

  def ==(other : Note)
    letter == other.letter && accidental == other.accidental && octave == other.octave
  end

  def to_s(io : IO)
    io << "#{letter}#{accidental}#{octave}"
  end
end
