class Mystic::Note
  getter letter : String
  getter accidental : String
  getter octave : Int32

  ACCIDENTAL_OFFSETS = {
    "#": 1,
    "x": 2,
    "b": -1,

    # Accept some unicode characters
    "♯": 1,
    "♭": -1,
    "𝄫": -2,
    "𝄪": 2,
  }

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

  protected def initialize(@letter, @accidental, @octave)
    @letter = @letter.upcase

    # Normalize accidentals to a standard format
    accidental_offset = Note.accidental_offset(@accidental)
    @accidental = Note.normalize_accidental(accidental_offset)
  end

  def initialize(s : String)
    pattern = (
      "^" \
      "([abcdefgABCDEFG])" \
      "([#♯x𝄪]*|[b♭𝄫]+)" \
      "(\\d+)?" \
      "$"
    )
    match = %r{#{pattern}}.match(s)

    raise Error.new("Invalid note name: #{s}") unless match

    letter = match[1].upcase
    accidental = match[2]
    octave = match[3]?.try &.to_i || BASE_OCTAVE
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

    accidental = Note.normalize_accidental(accidental_offset)

    Note.new(letter, accidental, octave)
  end

  protected def self.normalize_accidental(accidental_offset)
    case accidental_offset
    when .negative? then "b" * accidental_offset.abs
    when 1          then "#"
    when 2          then "x"
    when 3          then "#x"
    else
      # No standard way to denote > 3 sharps
      "#" * accidental_offset
    end
  end

  protected def self.accidental_offset(accidental)
    accidental.chars.sum { |c| ACCIDENTAL_OFFSETS.fetch(c.to_s, 0) }
  end

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
    Note.accidental_offset(accidental)
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

  def ==(other : Note)
    letter == other.letter && accidental == other.accidental && octave == other.octave
  end

  def to_s(io : IO)
    io << "#{letter}#{accidental}#{octave}"
  end
end
