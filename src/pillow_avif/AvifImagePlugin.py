from __future__ import division

from io import BytesIO
import sys

from PIL import Image, ImageFile

try:
    from pillow_avif import _avif

    SUPPORTED = True
except ImportError:
    SUPPORTED = False

# Decoder options as module globals, until there is a way to pass parameters
# to Image.open (see https://github.com/python-pillow/Pillow/issues/569)
DECODE_CODEC_CHOICE = "auto"
CHROMA_UPSAMPLING = "auto"

_VALID_AVIF_MODES = {"RGB", "RGBA"}


if sys.version_info[0] == 2:
    text_type = unicode  # noqa
else:
    text_type = str


def _accept(prefix):
    if prefix[4:12] in (b"ftypavif", b"ftypavis"):
        if not SUPPORTED:
            return (
                "image file could not be identified because AVIF "
                "support not installed"
            )
        return True


class AvifImageFile(ImageFile.ImageFile):

    format = "AVIF"
    format_description = "AVIF image"
    __loaded = -1
    __frame = 0

    def _open(self):
        self._decoder = _avif.AvifDecoder(
            self.fp.read(), DECODE_CODEC_CHOICE, CHROMA_UPSAMPLING
        )

        # Get info from decoder
        width, height, n_frames, mode, icc, exif, xmp = self._decoder.get_info()
        self._size = width, height
        self.n_frames = n_frames
        self.is_animated = self.n_frames > 1
        self.mode = self.rawmode = mode
        self.tile = []

        if icc:
            self.info["icc_profile"] = icc
        if exif:
            self.info["exif"] = exif
        if xmp:
            self.info["xmp"] = xmp

    def seek(self, frame):
        if not self._seek_check(frame):
            return

        self.__frame = frame

    def load(self):
        if self.__loaded != self.__frame:
            # We need to load the image data for this frame
            data, timescale, tsp_in_ts, dur_in_ts = self._decoder.get_frame(
                self.__frame
            )
            timestamp = round(1000 * (tsp_in_ts / timescale))
            duration = round(1000 * (dur_in_ts / timescale))
            self.info["timestamp"] = timestamp
            self.info["duration"] = duration
            self.__loaded = self.__frame

            # Set tile
            if self.fp and self._exclusive_fp:
                self.fp.close()
            self.fp = BytesIO(data)
            self.tile = [("raw", (0, 0) + self.size, 0, self.rawmode)]

        return super(AvifImageFile, self).load()

    def tell(self):
        return self.__frame


def _save_all(im, fp, filename):
    _save(im, fp, filename, save_all=True)


def _save(im, fp, filename, save_all=False):
    info = im.encoderinfo.copy()
    if save_all:
        append_images = list(info.get("append_images", []))
    else:
        append_images = []

    total = 0
    for ims in [im] + append_images:
        total += getattr(ims, "n_frames", 1)

    is_single_frame = total == 1

    duration = info.get("duration", 0)
    yuv_format = info.get("yuv_format", "4:2:0")
    qmin = info.get("qmin", 0)
    qmax = info.get("qmax", 0)
    qmin_alpha = info.get("qmin_alpha", 0)
    qmax_alpha = info.get("qmax_alpha", 0)
    speed = info.get("speed", 8)
    codec = info.get("codec", "auto")
    range_ = info.get("range", "full")

    icc_profile = info.get("icc_profile", im.info.get("icc_profile"))
    exif = info.get("exif", im.info.get("exif"))
    if isinstance(exif, Image.Exif):
        exif = exif.tobytes()
    xmp = info.get("xmp", im.info.get("xmp") or im.info.get("XML:com.adobe.xmp"))

    if isinstance(xmp, text_type):
        xmp = xmp.encode('utf-8')

    # Setup the AVIF encoder
    enc = _avif.AvifEncoder(
        im.size[0],
        im.size[1],
        yuv_format,
        qmin,
        qmax,
        qmin_alpha,
        qmax_alpha,
        speed,
        codec,
        range_,
        icc_profile or b'',
        exif or b'',
        xmp or b'',
    )

    # Add each frame
    frame_idx = 0
    frame_dur = 0
    cur_idx = im.tell()
    try:
        for ims in [im] + append_images:
            # Get # of frames in this image
            nfr = getattr(ims, "n_frames", 1)

            for idx in range(nfr):
                ims.seek(idx)
                ims.load()

                # Make sure image mode is supported
                frame = ims
                rawmode = ims.mode
                if ims.mode not in _VALID_AVIF_MODES:
                    alpha = (
                        "A" in ims.mode
                        or "a" in ims.mode
                        or (ims.mode == "P" and "A" in ims.im.getpalettemode())
                    )
                    rawmode = "RGBA" if alpha else "RGB"
                    frame = ims.convert(rawmode)

                # Update frame duration
                if isinstance(duration, (list, tuple)):
                    frame_dur = duration[frame_idx]
                else:
                    frame_dur = duration

                # Append the frame to the animation encoder
                enc.add(
                    frame.tobytes("raw", rawmode),
                    frame_dur,
                    frame.size[0],
                    frame.size[1],
                    rawmode,
                    is_single_frame,
                )

                # Update frame index
                frame_idx += 1

                if not save_all:
                    break

    finally:
        im.seek(cur_idx)

    # Get the final output from the encoder
    data = enc.finish()
    if data is None:
        raise OSError("cannot write file as AVIF (encoder returned None)")

    fp.write(data)


Image.register_open(AvifImageFile.format, AvifImageFile, _accept)
if SUPPORTED:
    Image.register_save(AvifImageFile.format, _save)
    Image.register_save_all(AvifImageFile.format, _save_all)
    Image.register_extensions(AvifImageFile.format, [".avif", ".avifs"])
    Image.register_mime(AvifImageFile.format, "image/avif")
