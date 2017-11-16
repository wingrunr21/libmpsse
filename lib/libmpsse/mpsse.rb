module LibMpsse
  class Mpsse
    attr_reader :context

    def initialize(mode:, freq: ClockRates[:four_hundred_khz], endianess: MSB)
      @context = Context.new(LibMpsse::MPSSE(mode, freq, endianess))

      # Enable TriState mode in I2C
      LibMpsse::Tristate(@context) if mode == Modes[:i2c]
    end

    def start
      LibMpsse::Start(context)
    end

    def stop
      LibMpsse::Stop(context)
    end

    def close
      LibMpsse::Close(context)
    end

    def read(size)
      data_ptr = LibMpsse::Read(context, size)
      data_ptr.read_bytes(size)
    end

    def read_bits(size = 8)
      LibMpsse::ReadBits(context, size)
    end

    def write(data)
      data = data.pack('C*')
      data_ptr = FFI::MemoryPointer.new(:uint8, data.bytesize)
      data_ptr.put_bytes(0, data)
      LibMpsse::Write(context, data_ptr, data.bytesize)
    end

    def ack
      LibMpsse::GetAck(context)
    end

    def ack=(ack_type)
      LibMpsse::SetAck(context, ack_type)
    end

    def send_nacks
      LibMpsse::SendNacks(context)
    end

    def send_acks
      LibMpsse::SendAcks(context)
    end

    def error_string
      LibMpsse::ErrorString(context)
    end
  end
end
