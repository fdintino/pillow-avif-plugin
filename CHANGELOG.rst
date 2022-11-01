Changelog
=========

1.3.1 (Nov 1, 2022)
-------------------

* **Fixed**: Distributed OS X wheels now include patch for libaom segmentation
  fault (see `AOMediaCodec/libavif#1190`_ and `aom@165281`_). The bundled
  static libaom was patched for all other wheels, but because of a build issue
  it was missing from the 1.3.0 mac wheels.

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
