require 'spec_helper'

describe LibMpsse::Mpsse do
  let(:libmpsse) { class_double('LibMpsse').as_stubbed_const(transfer_nested_constants: true) }
  let(:mpsse) { described_class.new(mode: LibMpsse::Modes[:i2c]) }
  let(:context) do
    ptr = FFI::MemoryPointer.new(LibMpsse::Context.size)
    struct = LibMpsse::Context.new FFI::Pointer.new(ptr)
    struct[:open] = 1
    struct[:mode] = LibMpsse::Modes[:i2c]
    struct
  end

  before(:each) do
    allow_any_instance_of(LibMpsse::Mpsse).to receive(:new_context).and_return(context)
  end

  describe '#initialize' do
    context 'when mode is i2c' do
      context 'when device is successfully opened' do
        let(:context) do
          { open: 1 }
        end

        it 'does not raise' do
          expect { mpsse }.not_to raise_error
        end
      end

      context 'when device cannot be opened' do
        let(:context) do
          { open: 0 }
        end

        it 'raises LibMpsse::Mpsse::CannotOpenError' do
          expect { mpsse }.to raise_error(LibMpsse::Mpsse::CannotOpenError)
        end
      end
    end

    context 'When `device` argument is given' do
      let(:device) do
        { vid: 0x0403, pid: 0x6010, interface: LibMpsse::Interface[:iface_any] }
      end
      let(:mpsse) { described_class.new(mode: LibMpsse::Modes[:i2c], device: device) }

      it 'does not raise' do
        expect { mpsse }.not_to raise_error
      end
    end
  end

  describe '.description' do
    it 'returns description' do
      allow_any_instance_of(LibMpsse::Mpsse).to receive(:new_context).and_return(context)

      expect(libmpsse).to receive(:GetDescription).and_return(FFI::MemoryPointer.from_string('My device'))
      expect(mpsse.description).to eq 'My device'
    end
  end

  describe '.set_direction' do
    let(:context) do
      { open: 1, mode: LibMpsse::Modes[:bitbang] }
    end
    context 'when SetDirection succeeds' do
      it 'does not raise' do
        expect(libmpsse).to receive(:SetDirection).and_return(LibMpsse::MPSSE_OK)
        expect { mpsse.direction(0xff) }.not_to raise_error
      end
    end

    context 'when SetDirection fails' do
      it 'raises LibMpsse::Mpsse::StatusCodeError' do
        expect(libmpsse).to receive(:SetDirection).and_return(LibMpsse::MPSSE_FAIL)
        expect(libmpsse).to receive(:ErrorString).and_return(FFI::MemoryPointer.from_string('something failed'))
        expect { mpsse.direction(0xff) }.to raise_error(LibMpsse::Mpsse::StatusCodeError, '-1: something failed')
      end
    end

    context 'when mode is not bitbang' do
      let(:context) do
        { open: 1, mode: LibMpsse::Modes[:i2c] }
      end

      it 'raises InvalidModeError' do
        expect { mpsse.direction(0xff) }.to raise_error(LibMpsse::Mpsse::InvalidModeError)
      end
    end
  end

  describe '.pin_mode' do
    context 'when a pin is set to high and PinHigh succeeds' do
      it 'does not raise' do
        expect(libmpsse).to receive(:PinHigh).and_return(LibMpsse::MPSSE_OK)
        expect { mpsse.pin_mode(1, :high) }.not_to raise_error
      end
    end

    context 'when a pin is set to low and PinLow succeeds' do
      it 'does not raise' do
        expect(libmpsse).to receive(:PinLow).and_return(LibMpsse::MPSSE_OK)
        expect { mpsse.pin_mode(1, :low) }.not_to raise_error
      end
    end

    context 'when a pin is set to high and PinHigh failes' do
      it 'raises LibMpsse::Mpsse::StatusCodeError' do
        expect(libmpsse).to receive(:PinHigh).and_return(LibMpsse::MPSSE_FAIL)
        expect(mpsse).to receive(:error_string).and_return('failed')
        expect { mpsse.pin_mode(1, :high) }.to raise_error(LibMpsse::Mpsse::StatusCodeError)
      end
    end

    context 'when invalid mode is given' do
      it 'raises InvalidModeError' do
        expect { mpsse.pin_mode(1, :invalid) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '.write_pins' do
    let(:context) do
      { open: 1, mode: LibMpsse::Modes[:bitbang] }
    end
    let(:mpsse) { described_class.new(mode: LibMpsse::Modes[:bitbang]) }

    context 'when set all pins to high' do
      it 'does not raise' do
        expect(libmpsse).to receive(:WritePins).and_return(LibMpsse::MPSSE_OK)
        expect { mpsse.write_pins(0xff) }.not_to raise_error
      end
    end

    context 'when mode is not bitbang mode' do
      let(:context) do
        { open: 1, mode: LibMpsse::Modes[:i2c] }
      end

      it 'raises InvalidModeError' do
        expect { mpsse.write_pins(0xff) }.to raise_error(LibMpsse::Mpsse::InvalidModeError)
      end
    end
  end

  describe '.read_pins' do
    let(:mpsse) { described_class.new(mode: LibMpsse::Modes[:bitbang]) }
    let(:context) do
      { open: 1, mode: LibMpsse::Modes[:bitbang] }
    end

    context 'when reads all pins' do
      it 'does not raise' do
        expect(libmpsse).to receive(:ReadPins).and_return(0xff).twice
        expect { mpsse.read_pins }.not_to raise_error
        expect(mpsse.read_pins).to eq 0xff
      end
    end

    context 'when mode is not bitbang' do
      let(:context) do
        { open: 1, mode: LibMpsse::Modes[:i2c] }
      end

      it 'raises InvalidModeError' do
        expect { mpsse.read_pins }.to raise_error(LibMpsse::Mpsse::InvalidModeError)
      end
    end
  end

  describe '.version' do
    it 'returns libmpsse version' do
      expect(libmpsse).to receive(:Version).and_return(FFI::MemoryPointer.from_string('1.2'))

      expect(mpsse.version).to eq '1.2'
    end
  end

  describe '.start' do
    context 'when Start() fails' do
      it 'raises LibMpsse::StatusCodeError' do
        allow(mpsse).to receive(:error_string).and_return('failed')
        allow(libmpsse).to receive(:Start).and_return(LibMpsse::MPSSE_FAIL)

        expect { mpsse.start }.to raise_error(LibMpsse::Mpsse::StatusCodeError)
      end
    end
  end

  describe '.stop' do
    context 'when Stop() fails' do
      it 'raises LibMpsse::StatusCodeError' do
        allow(mpsse).to receive(:error_string).and_return('failed')
        allow(libmpsse).to receive(:Stop).and_return(LibMpsse::MPSSE_FAIL)

        expect { mpsse.stop }.to raise_error(LibMpsse::Mpsse::StatusCodeError)
      end
    end
  end

  describe '.pin_state' do
    context 'when GPIOH7 is high' do
      it 'returns 1' do
        allow(libmpsse).to receive(:PinState).with(any_args, 7, -1).and_return(1)

        expect(mpsse.pin_state(7)).to eq 1
      end
    end
  end

  describe '.loopback' do
    context 'when enabled without error' do
      it 'does not raise' do
        allow(libmpsse).to receive(:SetLoopback).and_return(LibMpsse::MPSSE_OK)

        expect { mpsse.loopback(:enable) }.not_to raise_error
      end
    end

    context 'when disabled without error' do
      it 'does not raise' do
        allow(libmpsse).to receive(:SetLoopback).and_return(LibMpsse::MPSSE_OK)

        expect { mpsse.loopback(:disable) }.not_to raise_error
      end
    end

    context 'when SetLoopback() fails' do
      it 'raises StatusCodeError' do
        allow(libmpsse).to receive(:SetLoopback).and_return(LibMpsse::MPSSE_FAIL)
        allow(libmpsse).to receive(:ErrorString).and_return(FFI::MemoryPointer.from_string('failed'))

        expect { mpsse.loopback(:enable) }.to raise_error(LibMpsse::Mpsse::StatusCodeError)
      end
    end

    context 'when argument is invalid' do
      it 'raises ArgumentError' do
        expect { mpsse.loopback(:invalid) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '.cs_idle' do
    context 'when state is invalid' do
      it 'raises ArgumentError' do
        expect { mpsse.cs_idle(:foo) }.to raise_error(ArgumentError)
      end
    end
  end
end
