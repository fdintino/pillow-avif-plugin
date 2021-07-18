"""
Helper functions (from Pillow).
"""

import gc
from io import BytesIO
import logging
import os
from struct import unpack
import sys
import tempfile

import pytest

from PIL import Image, ImageMath


logger = logging.getLogger(__name__)
CURR_DIR = os.path.dirname(os.path.dirname(__file__))


HAS_UPLOADER = False

if os.environ.get("SHOW_ERRORS", None):
    # local img.show for errors.
    HAS_UPLOADER = True

    class test_image_results:
        @staticmethod
        def upload(a, b):
            a.show()
            b.show()


elif "GITHUB_ACTIONS" in os.environ:
    HAS_UPLOADER = True

    class test_image_results:
        @staticmethod
        def upload(a, b):
            dir_errors = os.path.join(os.path.dirname(__file__), "errors")
            os.makedirs(dir_errors, exist_ok=True)
            tmpdir = tempfile.mkdtemp(dir=dir_errors)
            a.save(os.path.join(tmpdir, "a.png"))
            b.save(os.path.join(tmpdir, "b.png"))
            return tmpdir


else:
    try:
        import test_image_results

        HAS_UPLOADER = True
    except ImportError:
        pass


def convert_to_comparable(a, b):
    new_a, new_b = a, b
    if a.mode == "P":
        new_a = Image.new("L", a.size)
        new_b = Image.new("L", b.size)
        new_a.putdata(a.getdata())
        new_b.putdata(b.getdata())
    elif a.mode == "I;16":
        new_a = a.convert("I")
        new_b = b.convert("I")
    return new_a, new_b


def assert_image(im, mode, size, msg=None):
    if mode is not None:
        assert im.mode == mode, msg or "got mode %r, expected %r" % (im.mode, mode)

    if size is not None:
        assert im.size == size, (
            msg or "got size %r, expected %r" % (im.size, size)
        )


def assert_image_similar(a, b, epsilon, msg=None):
    assert a.mode == b.mode, msg or "got mode %r, expected %r" % (a.mode, b.mode)
    assert a.size == b.size, msg or "got size %r, expected %r" % (a.size, b.size)

    a, b = convert_to_comparable(a, b)

    diff = 0
    for ach, bch in zip(a.split(), b.split()):
        chdiff = ImageMath.eval("abs(a - b)", a=ach, b=bch).convert("L")
        diff += sum(i * num for i, num in enumerate(chdiff.histogram()))

    ave_diff = diff / (a.size[0] * a.size[1])
    try:
        assert epsilon >= ave_diff, (
            (msg or "")
            + " average pixel value difference %.04f > epsilon %.04f" % (
                ave_diff, epsilon)
        )
    except Exception as e:
        if HAS_UPLOADER:
            try:
                url = test_image_results.upload(a, b)
                logger.error("Url for test images: %s" % url)
            except Exception:
                pass
        raise e


def assert_image_similar_tofile(a, filename, epsilon, msg=None, mode=None):
    with Image.open(filename) as img:
        if mode:
            img = img.convert(mode)
        assert_image_similar(a, img, epsilon, msg)


@pytest.mark.skipif(sys.platform.startswith("win32"), reason="Requires Unix or macOS")
class PillowLeakTestCase:
    # requires unix/macOS
    iterations = 100  # count
    mem_limit = 512  # k

    def _get_mem_usage(self):
        """
        Gets the RUSAGE memory usage, returns in K. Encapsulates the difference
        between macOS and Linux rss reporting

        :returns: memory usage in kilobytes
        """

        from resource import RUSAGE_SELF, getrusage

        mem = getrusage(RUSAGE_SELF).ru_maxrss
        if sys.platform == "darwin":
            # man 2 getrusage:
            #     ru_maxrss
            # This is the maximum resident set size utilized (in bytes).
            return mem / 1024  # Kb
        else:
            # linux
            # man 2 getrusage
            #        ru_maxrss (since Linux 2.6.32)
            #  This is the maximum resident set size used (in kilobytes).
            return mem  # Kb

    def _test_leak(self, core):
        start_mem = self._get_mem_usage()
        for cycle in range(self.iterations):
            core()
            gc.collect()
            mem = self._get_mem_usage() - start_mem
            msg = "memory usage limit exceeded in iteration %s" % cycle
            assert mem < self.mem_limit, msg


def hopper(mode=None, cache={}):
    if mode is None:
        # Always return fresh not-yet-loaded version of image.
        # Operations on not-yet-loaded images is separate class of errors
        # what we should catch.
        return Image.open("%s/tests/images/hopper.ppm" % CURR_DIR)
    # Use caching to reduce reading from disk but so an original copy is
    # returned each time and the cached image isn't modified by tests
    # (for fast, isolated, repeatable tests).
    im = cache.get(mode)
    if im is None:
        if mode == "F":
            im = hopper("L").convert(mode)
        elif mode[:4] == "I;16":
            im = hopper("I").convert(mode)
        else:
            im = hopper().convert(mode)
        cache[mode] = im
    return im.copy()


def is_ascii(s):
    for char in s:
        if isinstance(char, str):
            char = ord(char)
        if char < 0x20 or char > 0x7e:
            return False
    return True


def has_alpha_premultiplied(im_bytes):
    stream = BytesIO(im_bytes)
    length = len(im_bytes)
    while stream.tell() < length:
        start = stream.tell()
        size, boxtype = unpack(">L4s", stream.read(8))
        if not is_ascii(boxtype):
            return False
        if size == 1:  # 64bit size
            size, = unpack(">Q", stream.read(8))
        end = start + size
        version, _ = unpack(">B3s", stream.read(4))
        if boxtype in (b"ftyp", b"hdlr", b"pitm", b"iloc", b"iinf"):
            # Skip these boxes
            stream.seek(end)
            continue
        elif boxtype == b"meta":
            # Container box possibly including iref prem, continue to parse boxes
            # inside it
            continue
        elif boxtype == b"iref":
            while stream.tell() < end:
                _, iref_type = unpack(">L4s", stream.read(8))
                version, _ = unpack(">B3s", stream.read(4))
                if iref_type == b"prem":
                    return True
                stream.read(2 if version == 0 else 4)
        else:
            return False
    return False
