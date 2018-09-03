module LibMpsse
  class Mpsse
    attr_reader :context

    # Open the device and initialize itself
    #
    # @param mode [LibMpsse::Modes] one of operation modes, one of
    #   {LibMpsse::Modes}
    # @param freq [LibMpsse::ClockRates] Clock frequency
    # @param endianess [Integer] {LibMpsse::MSB} or {LibMpsse::LSB}
    # @param device [Hash] choose device with specific attributes. some keys
    #   may be omitted, in which case default values are used.
    #   * :vid (Integer) vendor ID, default is `0x0403` for FTDI
    #   * :pid (Integer) product ID, default is  `0x6010` for FT2232
    #   * :interface ({LibMpsse::Interface}) interface to use,  default is `:iface_any`.
    #   * :index (Integer) device index, zero for the first device
    def initialize(mode:, freq: ClockRates[:four_hundred_khz], endianess: MSB, device: {})
      @context = new_context(mode: mode, freq: freq, endianess: endianess, device: device)
      raise CannotOpenError, 'Cannot open device' if (@context[:open]).zero?
    end

    def new_context(mode:, freq:, endianess:, device:)
      if device.empty?
        Context.new(LibMpsse::MPSSE(mode, freq, endianess))
      else
        Context.new(
          LibMpsse::OpenIndex(
            device.key?(:vid) ? device[:vid] : 0x0403, device.key?(:pid) ? device[:pid] : 0x6010,
            mode, freq, endianess, device.key?(:interface) ? device[:interface] : Interface[:iface_any],
            nil, nil, device.key?(:index) ? device[:index] : 0
          )
        )
      end
    end

    # Send data start condition.
    #
    # @raise [StatusCodeError]
    def start
      check_libmpsse_error(LibMpsse::Start(context))
    end

    # Send data stop condition.
    #
    # @raise [StatusCodeError]
    def stop
      check_libmpsse_error(LibMpsse::Stop(context))
    end

    # Close the device.
    def close
      LibMpsse::Close(context)
    end

    # Read array of uint8_t from bus.
    #
    # @param size [Integer] size to read
    # @return [Array<Integer>] array of bytes
    def read(size)
      data_ptr = LibMpsse::Read(context, size)
      data_ptr.read_array_of_type(FFI::TYPE_UINT8, :read_uint8, size)
    end

    # Performs a bit-wise read of up to 8 bits.
    #
    # @param size [Integer] number of bits to read
    # @return an 8-bit byte containing the read bits
    def read_bits(size = 8)
      LibMpsse::ReadBits(context, size)
    end

    # Send data out via the selected serial protocol.
    #
    # @param data [Array<Integer>] data to write
    # @raise [StatusCodeError]
    def write(data)
      data = data.pack('C*')
      data_ptr = FFI::MemoryPointer.new(:uint8, data.bytesize)
      data_ptr.put_bytes(0, data)
      check_libmpsse_error(LibMpsse::Write(context, data_ptr, data.bytesize))
    end

    # Get ACK from bus
    #
    # @return [Integer] either an ACK (0) or a NACK (1).
    def ack
      LibMpsse::GetAck(context)
    end

    # Sets the transmitted ACK bit.
    # @param ack_type [Integer] 0 to send ACKs, 1 to send NACKs.
    def ack=(ack_type)
      LibMpsse::SetAck(context, ack_type)
    end

    # Causes libmpsse to send NACKs after each read byte in I2C mode.
    def send_nacks
      LibMpsse::SendNacks(context)
    end

    # Causes libmpsse to send ACKs after each read byte in I2C mode.
    def send_acks
      LibMpsse::SendAcks(context)
    end

    # Retrieves the last error string from libftdi.
    # @return [String]
    def error_string
      str_p = LibMpsse::ErrorString(context)
      str_p.read_string
    end

    # Returns the description of the FTDI chip, if any.
    # @return [String]
    def description
      str_p = LibMpsse::GetDescription(context)
      str_p.read_string
    end

    # Returns the libmpsse version number.
    # @return [String]
    def version
      str_p = LibMpsse::Version(nil)
      str_p.read_string
    end

    # Sets the input/output direction of all pins. For use in BITBANG mode
    # only.
    #
    # @param direction [Integer] Byte indicating input/output direction of
    #   each bit. 0 is input, and 1 is output.
    #
    # @raise [StatusCodeError] if SetDirection does not return
    #   {LibMpsse::MPSSE_OK}
    # @raise [InvalidModeError] When mode is not LibMpsse::Modes[:bitbang]
    def direction(direction)
      raise InvalidModeError.new(context[:mode], 'bitbang') unless context[:mode] == LibMpsse::Modes[:bitbang]
      err = LibMpsse::SetDirection(context, direction)
      check_libmpsse_error(err)
    end

    # Set a pin to specified state, either high or low.
    #
    # @param pin [Integer] Pin number
    # @param mode [Symbol] `:high` or `:low`
    # @raise [ArgumentError] if mode is invalid
    # @raise [StatusCodeError] if libmpsse does not return {LibMpsse::MPSSE_OK}
    def pin_mode(pin, mode)
      case mode
      when :high
        check_libmpsse_error(LibMpsse::PinHigh(pin))
      when :low
        check_libmpsse_error(LibMpsse::PinLow(pin))
      else
        raise ArgumentError, format('invalid mode `%<mode>s`: mode must be either :high or :low', mode: mode)
      end
    end

    # Sets the input/output value of all pins. For use in BITBANG mode only.
    #
    # @param bits [Integer] Byte indicating bit hi/low value of each bit.
    # @raise [InvalidModeError] When mode is not LibMpsse::Modes[:bitbang]
    def write_pins(bits)
      raise InvalidModeError.new(context[:mode], 'bitbang') unless context[:mode] == LibMpsse::Modes[:bitbang]
      check_libmpsse_error(LibMpsse::WritePins(context, bits))
    end

    # Reads the state of the chip's pins. For use in BITBANG mode only.
    #
    # @raise [InvalidModeError] When mode is not LibMpsse::Modes[:bitbang]
    # @return [Integer] a byte with the corresponding pin's bits set to 1 or 0.
    def read_pins
      raise InvalidModeError.new(context[:mode], 'bitbang') unless context[:mode] == LibMpsse::Modes[:bitbang]
      LibMpsse::ReadPins(context)
    end

    # Checks if a specific pin is high or low. For use in BITBANG mode only if
    # state is not given.
    #
    # @param pin [GpioPins] pin number
    # @param state [Integer] pin state. when state is not given, or is nil,
    #   actual pin state is read by ReadPins().
    # @return [Integer] Returns a 1 if the pin is high, 0 if the pin is low.
    def pin_state(pin, state = nil)
      LibMpsse::PinState(context, pin, state.nil? ? -1 : state)
    end

    # Enable / disable internal loopback.
    # @param mode [Synbol] either `:enable` or `:disable`
    # @raise [StatusCodeError] when SetLoopback() failed
    # @raise [ArgumentError] when invalid argument was given
    def loopback(mode)
      raise ArgumentError, 'mode must be :enable or :disable' unless %i[enable disable].include? mode
      check_libmpsse_error(LibMpsse::SetLoopback(context, mode == :enable ? 1 : 0))
    end

    # Sets the idle state of the chip select pin. CS idles high by default.
    #
    # @param state [:high, :low] desired idle state
    # @raise [ArgumentError] when state is not ;high or :low
    def cs_idle(state)
      raise ArgumentError, 'state must be `:high` or `:low`' unless %i[high low].include? state
      LibMpsse::SetCSIdle(context, state == :high ? 1 : 0)
    end

    private

    def check_libmpsse_error(err)
      raise StatusCodeError.new(err, error_string) if err != LibMpsse::MPSSE_OK
    end
  end
end
