Changelog
=========

1.5.1
-----

* **CI**: Update libavif to 1.2.1. The only library version change since
  1.5.0 is SVT-AV1, which was upgraded from 3.0.0 to 3.0.1. See the table
  below for all AVIF codec versions in this release.

.. table::

  ===========  ==========
  **libavif**  **1.2.1**
  libaom       3.12.0
  dav1d        1.5.1
  **SVT-AV1**  **3.0.1**
  rav1e        0.7.1
  ===========  ==========

1.5.0 (Mar 7, 2025)
-------------------

* **Fixed**: Convert AVIF irot and imir into EXIF orientation when decoding
  an image, in `#70`_. EXIF orientation has been preserved by the encoder
  since 1.4.2, which is when we started setting irot and imir. But if an AVIF
  image with non-default irot or imir values was converted to another format,
  its orientation would be lost.
* **Fixed**: ``pillow_avif.AvifImagePlugin.CHROMA_UPSAMPLING`` is now actually
  used when decoding an image, in `#70`_.
* **Fixed**: ``TypeError`` when saving images with float frame durations, by
  `@BlackSmith`_ in `#68`_ (merged from `#71`_)
* **Added**: Python 3.13 free-thread mode support (experimental).
*  **CI**: Update libavif to 1.2.0 (`4eb0a40`_, 2025-03-05); publish wheels
   for python 3.13. See the table below for the current AVIF codec versions.
   Libraries whose versions have changed since the last pillow-avif-plugin
   release are bolded.

.. table::

  ===========  ==========
  **libavif**  **1.2.0** (`4eb0a40`_)
  **libaom**   **3.12.0**
  **dav1d**    **1.5.1**
  **SVT-AV1**  **3.0.0**
  rav1e        0.7.1
  ===========  ==========

.. _#68: https://github.com/fdintino/pillow-avif-plugin/pull/68
.. _#70: https://github.com/fdintino/pillow-avif-plugin/pull/70
.. _#71: https://github.com/fdintino/pillow-avif-plugin/pull/71
.. _4eb0a40: https://github.com/AOMediaCodec/libavif/commit/4eb0a40fb06612adf53650a14c692eaf62c068e6
.. _@BlackSmith: https://github.com/BlackSmith

1.4.6 (Jul 14, 2024)
--------------------

* **Fixed**: macOS arm64 illegal instruction segmentation fault with aom
  encoding in `#60`_ and `#61`_; fixes `#59`_.

.. _#59: https://github.com/fdintino/pillow-avif-plugin/issues/59
.. _#60: https://github.com/fdintino/pillow-avif-plugin/pull/60
.. _#61: https://github.com/fdintino/pillow-avif-plugin/pull/61

1.4.4 (Jul 8, 2024)
-------------------

*  **CI**: bump libavif to `e10e6d9`_ (2024-07-01); fix CI build issues
   in `#53`_. See table below for new versions (all versions are
   upgrades from the 1.4.3 release).

   +------------------------------------+-------------------------+
   | **libavif**                        | **1.0.3** (`e10e6d9`_)  |
   +------------------------------------+-------------------------+
   | **libaom**                         | **3.9.1**               |
   +------------------------------------+-------------------------+
   | **dav1d**                          | **1.4.3**               |
   +------------------------------------+-------------------------+
   | **SVT-AV1**                        | **2.1.1**               |
   +------------------------------------+-------------------------+
   | **rav1e**                          | **0.7.1**               |
   +------------------------------------+-------------------------+

*  **Feature**: Allow users to pass ``max_threads`` to the avif encoder via
   ``Image.save`` by `@yit-b`_ in `#54`_, originally in `#49`_.

*  **Feature**: Let users pass ``max_threads`` as an argument to
   ``_avif.AvifDecoder`` by `@yit-b`_ in `#50`_.

*  **CI**: build SVT-AV1 for aarch64 or arm64 by `@RaphaelVRossi`_ in `#38`_.

*  **Fixed**: keep alpha channel for images with mode P and custom
   transparency in `#56`_; fixes `#48`_.

*  **Fixed**: disable decoder strictness for ``clap`` and ``pixi`` properties
   in `#57`_. fixes `#13`_ and `#28`_.

*  **CI**: lint secrets permission error and macOS GHA runner homebrew
   ``PATH`` bug in `#55`_.

.. _e10e6d9: https://github.com/AOMediaCodec/libavif/commit/e10e6d98e6d1dbcdd409859a924d1b607a1e06dc
.. _#53: https://github.com/fdintino/pillow-avif-plugin/pull/53
.. _#54: https://github.com/fdintino/pillow-avif-plugin/pull/54
.. _#49: https://github.com/fdintino/pillow-avif-plugin/pull/49
.. _#50: https://github.com/fdintino/pillow-avif-plugin/pull/50
.. _@RaphaelVRossi: https://github.com/RaphaelVRossi
.. _#38: https://github.com/fdintino/pillow-avif-plugin/pull/38
.. _#56: https://github.com/fdintino/pillow-avif-plugin/pull/56
.. _#48: https://github.com/fdintino/pillow-avif-plugin/issues/48
.. _#57: https://github.com/fdintino/pillow-avif-plugin/pull/57
.. _#13: https://github.com/fdintino/pillow-avif-plugin/issues/13
.. _#28: https://github.com/fdintino/pillow-avif-plugin/issues/28
.. _#55: https://github.com/fdintino/pillow-avif-plugin/pull/55

1.4.3 (Feb 8, 2024)
-------------------

-  **Fixed**: Limit maxThreads to 64 for aom encodes by `@yit-b`_ (`#41`_).
   Fixes `#23`_.
-  **Tests**: fix pytest deprecation warning (`#42`_).
-  **CI**: update libavif to v1.0.3 and update transitive dependencies (`#43`_).
   See table below; changes from previous release in bold.

=========== =========
**libavif** **1.0.3**
**libaom**  **3.8.1**
**dav1d**   **1.3.0**
SVT-AV1     1.7.0
**rav1e**   **0.7.0**
=========== =========

.. _@yit-b: https://github.com/yit-b
.. _#41: https://github.com/fdintino/pillow-avif-plugin/pull/41
.. _#42: https://github.com/fdintino/pillow-avif-plugin/pull/42
.. _#23: https://github.com/fdintino/pillow-avif-plugin/issues/23
.. _#43: https://github.com/fdintino/pillow-avif-plugin/pull/43

1.4.2 (Jan 9, 2024)
-------------------

* **Fixed**: Convert EXIF orientation to AVIF irot and imir in `#40`_.

.. _#40: https://github.com/fdintino/pillow-avif-plugin/pull/40

1.4.1 (Oct 12, 2023)
--------------------

* **Fixed**: Issue `#32`_ cannot access local variable 'quality' in `#33`_.

.. _#32: https://github.com/fdintino/pillow-avif-plugin/issues/32
.. _#33: https://github.com/fdintino/pillow-avif-plugin/pull/33

1.4.0 (Sep 24, 2023)
--------------------

*  **Feature**: Support new libavif quality encoder option. This
   replaces the (now deprecated) qmin and qmax options in libavif 1.x
*  **CI**: Publish python 3.12 wheels
*  **CI**: Stop publishing manylinux1 and 32-bit wheels, following the
   lead of Pillow
*  **CI**: Fix zlib 1.2.11 download link invalid, update to 1.2.13 by
   `@gamefunc`_ in `#22`_
*  **CI**: Update bundled libraries (`#27`_) (see table below,
   changes from previous release in bold)
*  **CI**: Bundle rav1e in windows wheels (fixes `#25`_).

=========== =========
**libavif** **1.0.1**
**libaom**  **3.7.0**
**dav1d**   **1.2.1**
**SVT-AV1** **1.7.0**
**rav1e**   **0.6.6**
=========== =========

.. _@gamefunc: https://github.com/gamefunc
.. _#22: https://github.com/fdintino/pillow-avif-plugin/pull/22
.. _#27: https://github.com/fdintino/pillow-avif-plugin/pull/27
.. _#25: https://github.com/fdintino/pillow-avif-plugin/issues/25

1.3.1 (Nov 2, 2022)
-------------------

* **Fixed**: Distributed OS X wheels now include patch for libaom segmentation
  fault (see `AOMediaCodec/libavif#1190`_ and `aom@165281`_). The bundled
  static libaom was patched for all other wheels, but because of a build issue
  it was missing from the 1.3.0 mac wheels.
* **CI**: Python 3.6 wheels are no longer being packaged and distributed,
  ahead of support being dropped in the next major release.

.. _AOMediaCodec/libavif#1190: https://github.com/AOMediaCodec/libavif/issues/1190
.. _aom@165281: https://aomedia-review.googlesource.com/c/aom/+/165281/1

1.3.0 (Oct 29, 2022)
--------------------

* **Changed**: Default ``quality`` changed to 75 (was previously 90)
* **Changed**: Default ``speed`` changed to 6 (was previously 8)
* **Added**: autotiling feature (default ``True`` if ``tile_rows`` and
  ``tile_cols`` are unset, can be disabled with ``autotiling=False`` passed to
  ``save()``).
* **Fixed**: ``tile_cols`` encoder setting (the ``save()`` method was using
  the value passed to ``tile_rows`` instead)
* **Fixed**: Attempts to open non-AV1 images in HEIF containers (e.g. HEIC)
  now raise UnidentifiedImageError, not ValueError. Fixes `#19`_.
* **CI**: manylinux2014 aarch64 wheels
* **CI**: bundle libyuv
* **CI**: Python 3.11 wheels
* **CI**: Update bundled libraries (see table below, changes from previous
  release in bold)

.. _#19: https://github.com/fdintino/pillow-avif-plugin/issues/19

.. table::

  ===========  ==========
  **libavif**  **0.11.0**
  **libaom**   **3.5.0**
  **dav1d**    **1.0.0**
  **SVT-AV1**  **1.3.0**
  rav1e        0.5.1
  ===========  ==========

1.2.2 (Apr 20, 2022)
--------------------

* **CI**: Build musllinux wheels
* **CI**: Update bundled libraries (see table below, changes from previous
  release in bold)

.. table::

  ===========  ==========
  **libavif**  **0.10.1**
  **libaom**   **3.3.0**
  **dav1d**    **1.0.0**
  **SVT-AV1**  **0.9.1**
  **rav1e**    **0.5.1**
  ===========  ==========

1.2.1 (Oct 14, 2021)
--------------------

* **Fixed**: Accept all AVIF compatible brands in the FileTypeBox. Fixes `#5`_.
* **CI**: Add Python 3.10 wheels
* **CI**: Add OS X ARM64 wheels
* **CI**: Update bundled libraries (see table below, changes from previous
  release in bold)

.. _#5: https://github.com/fdintino/pillow-avif-plugin/issues/5

.. table::

  ===========  ==========
  libavif      0.9.2
  libaom       2.0.2
  **dav1d**    **0.9.2**
  SVT-AV1      0.8.7
  rav1e        0.4.0
  ===========  ==========

1.2.0 (Jul 19, 2021)
--------------------

* **Added**: ``tile_rows`` encoder setting
* **Added**: ``alpha_premultiplied`` encoder setting
* **Added**: ``advanced`` encoder setting to pass codec-specific key-value
  options
* **CI**: Update bundled libraries (see table below, changes from previous
  release in bold)

.. table::

  ===========  ==========
  **libavif**  **0.9.2**
  libaom       2.0.2
  **dav1d**    **0.9.0**
  **SVT-AV1**  **0.8.7**
  rav1e        0.4.0
  ===========  ==========

1.1.0 (Apr 11, 2021)
--------------------

* **Added**: ``quality`` kwarg for ``save`` that maps to min and max quantizer
  values.
* **Changed**: ``yuv_format`` kwarg renamed ``subsampling``.
* **CI**: Update bundled libraries (see table below, changes from previous
  release in bold)



.. table::

  ======== ========
  libavif  0.9.0
  libaom   2.0.2
  dav1d    0.8.2
  SVT-AV1  0.8.6
  rav1e    0.4.0
  ======== ========

1.0.1 (Feb 23, 2021)
--------------------

* Fix: Allow saving of a single image from a sequence. Fixes `#1`_.

.. _#1: https://github.com/fdintino/pillow-avif-plugin/issues/1

1.0.0 (Feb 1, 2021)
-------------------

Initial release
