# Changelog

## [0.3.11]

- Fix `TransitionToImage` BoxFit again.

## [0.3.10]

- Improve zoomable_widget's bounce animation.
- Fix the placeholder stretched issue.

## [0.3.9]

- Update http dependency.
- Catch the bad images from remote.

## [0.3.8]

- Check if `_imageInfo` is null.

## [0.3.7]

- Give the cache file path.
- Fix `TransitionToImage` BoxFit behavior.
- Better impl on retry feature.
- Remove quiver dependency.

## [0.3.6]

- Add `fallbackImage` in `AdvancedNetworkImage`.
- Fix bug on `retryLimit`.
- Tweek the `GestureDetector` in `TransitionToImage`.

## [0.3.5]

- Add a flag to disable interior `GestureDetector` in `TransitionToImage`.
- Fix bug on printing error.

## [0.3.4]

- Add callback on `AdvancedNetworkImage`.
- Add a bounce back boundary.
- Add double tap step zoom.

## [0.3.3]

- Move the `ZoomableWidget`'s origin point to screen's center.

## [0.3.2]

- Add `multiFingersPan` and remove `enablePan`.

## [0.3.1]

- Now allow `ZoomableWidget` to pan with single finger.

## [0.3.0+1]

- Update README.md.

## [0.3.0]

- Add ZoomableList.

## [0.2.11]

- Update placeholder in TransitionToImage.

## [0.2.10]

- Add image fit option to TransitionToImage.

## [0.2.9+1]

- Change dependencies version.

## [0.2.9]

- Fix ConcurrentModificationError again.

## [0.2.8]

- `ZoomableWidget` support boundary for now.

## [0.2.7]

- Drop support for ETag checking.

## [0.2.6]

- Fix an issue that causes a ConcurrentModificationError.

## [0.2.5]

- Move the cache files from app folder to temporary folder.

## [0.2.4]

- Add `reloadWidget` and `fallbackWidget` to `TransitionToImage` widget.

## [0.2.3]

- Add a minimum png to avoid some issues.
- Add a reload button to `TransitionToImage` widget to reload the image if fetching network image failed.

## [0.2.2+1]

- Update some dependencies.

## [0.2.2]

- Adapt to dart 2 preview.

## [0.2.1]

- Support fallback image after retrying failed.

## [0.2.0+1]

- Cleanup example code.

## [0.2.0]

- Add `timeoutDuration` parameter, make some tweaks and add some doc comments to `AdvancedNetworkImage` imageprovider.

- Make some tweaks for `TransitionToImage` widget.

- Fix the panning issue which would shift when the scale is not 1.0 for `ZoomableWidget`.

## [0.1.10]

- Catch exception for file not found.

## [0.1.9]

- Add default blendmode to `TransitionToImage` widget.

## [0.1.8]

- Fix the listener leak problem for the `TransitionToImage` widget.

## [0.1.7]

- Add a `TransitionToImage` Widget, optimize `ZoomableWidget` and update example.

## [0.1.6+2]

- Downgrade `http` version.

## [0.1.6+1]

- Upgrade the dart SDK version.

## [0.1.6]

- Add animation to `ZoomableWidget`.

## [0.1.5]

- Update `ZoomableWidget`.

## [0.1.4]

- Update example.

## [0.1.3]

- Fix dependencies with http package.

## [0.1.2]

- Upgrade some dependencies version.

## [0.1.1]

- Downgrade some packages version.

## [0.1.0]

- An advanced image provider and a widget with zooming and panning.