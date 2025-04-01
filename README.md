# SimpleScope

A simple oscilloscope intended for use with [Arduino UNO](https://docs.arduino.cc/hardware/uno-rev3/) and [Processing](https://processing.org/).
- 2 channels
- Up to 15 bits of precision per channel
- Can export samples to CSV or TSV


## Changing Sample Rate

The Arduino sketch samples at 5 kHz due to the limits of how fast the Arduino UNO can sample with `analogRead`.
It is possible to change the sample rate by adjusting the following variables:
- `PERIOD_US` (us) in Arduino defines the time between samples.
- `SAMPLE_RATE` (Hz) in Processing should be equal to `1e6 / PERIOD_US`.
- `BAUD` in both Processing and Arduino. This needs to be at least 36 times `SAMPLE_RATE` to not overload the Serial bus.
	- This is because 4 bytes of data are sent per sample, and each byte has an extra stop bit, so 36 bits in total.


## Changing Voltage Range

If the analog range is different than 0-5 Volts, then these variables need to be changed:
- `MIN_VOLTS` in Processing
- `MAX_VOLTS` in Processing


## Changing Analog Precision

The precision of the value from `analogRead` can be changed with [analogReadResolution](https://docs.arduino.cc/language-reference/en/functions/analog-io/analogReadResolution) if hardware supports it, or your hardware may have different default precision.
See [this page](https://docs.arduino.cc/language-reference/en/functions/analog-io/analogRead) to see what analog precision Arduino hardware supports.

When changing resolution to `n` bits of precision, these variables need to be changed:
- `analogReadResolution(n)` in Arduino, if hardware supports it
- `MAX_SAMPLE_VALUE` in Processing is set to `2^n - 1`

The leftmost bit of each channel's value is used to distinguish the channels. This is used to sync the signal, but limits the precision of each channel to 15 bits. Using hardware with 16 or more bits of analog precision will require truncating the value to 15 bits.


## Exporting

Pressing 'E' in the Processing sketch will export all current samples in chronological order, which is different from how they are displayed.
More recent samples overwrite older samples from left to right, but the leftmost sample is not necessarily the oldest.


## Notes

The Processing sketch may not work properly for versions before Processing 3.