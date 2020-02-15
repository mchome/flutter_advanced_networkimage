# Changelog

## [0.8.0]

- Remove `disableMemoryCache` in AdvancedNetworkImage.

## [0.7.0]

- Update dependency.
- Basic web support for image.

## [0.6.4]

- Update dependency.

## [0.6.3]

- Improve performance of progress-tracked http image download.
- Update dependency.

## [0.6.2]

- Fix longPressForceRefresh type issue.

## [0.6.1]

- Bump SDK version.

## [0.6.0]

- Update dependency.
- Use new flutter api.
- Add longPressForceRefresh in TranstionToImage.
- Add removeFromCache.
- Fix DiskCache().evict() always return true.
- Expose loadFromRemote for provider.
- Support range fetch in retry state.
- Add skipRetryStatusCode.
- Add imageFilter.
- Update example.

## [0.6.0-alpha.1]

- Update dependency.
- Use new flutter api.

## [0.5.0]

- Update dependency.
- Use new flutter api.

## [0.5.0-alpha.3]

- Update flutter_svg.

## [0.5.0-alpha.2]

- Update provider.

## [0.5.0-alpha.1]

- Update folders.

## [0.4.15]

- `TransitionToImage`: Adding color property for use with BlendMode.
- Initial data in `keepCacheHealth`.

## [0.4.14]

- Update flutter_svg to 0.12.0.
- Exclude header in Object.== and Object.hashcode.

## [0.4.13]

- `AdvancedNetworkImage`: Replace the future with callback to avoid recall in `getRealUrl`.
- `AdvancedNetworkSvg`: Replace the future with callback to avoid recall in `getRealUrl`.

## [0.4.12]

- `ZoomableWidget`: rewrite boundary.
- `zoomable_list`: `childKey` is now deprecated.

## [0.4.11]

- `AdvancedNetworkSvg`: adapt flutter_svg 0.10.4.

## [0.4.10]

- `AdvancedNetworkImage`: fix missing content-length problem.

## [0.4.9]

- `AdvancedNetworkImage`: fix gzip download problem.

## [0.4.8]

- `AdvancedNetworkImage`: add `preProcessing` & `postProcessing`.

## [0.4.7]

- `AdvancedNetworkImage`: add `disableMemoryCache`.
- `TransitionToImage`: add `disableMemoryCacheIfFailed`.
- `ZoomableWidget` & `ZoomableList`: add a non-physical fling in `enableFling` & `flingFactor`.

## [0.4.6]

- `TransitionToImage`: add `forceRebuildWidget`.
- `AdvancedNetworkImage` & `AdvancedNetworkSvg`: add `fallbackAssetImage`.

## [0.4.5]

- Update `path_provider` dependency.
- Add download test and update download error function.

## [0.4.4]

- `TransitionToImage`: add `disableMemoryCache`;
- `TransitionToImage`: add `loadedCallback` & `loadFailedCallback`.

## [0.4.3]

- `AdvancedNetworkImage`: fix download error.

## [0.4.2]

- `AdvancedNetworkImage`: download method fallback.

## [0.4.1]

- Fix `TransitionToImage` loadingWidget & placeholder padding problem.
- Remove `loadingWidget` deprecated status.

## [0.4.0]

- `flutter_advanced_networkimage`: add `cacheRule`, `loadingProgress`
    and `getRealUrl`.
- `flutter_advanced_networksvg:`: new in 0.4.0.
- `transition_to_image`: match `Image` widget option(breaking change),
    `loadingWidget` is deprecated, use `loadingWidgetBuilder`(display progress),
    add `borderRadius`, fix setState() called after dispose().
- `disk_cache`: new in 0.4.0.
- `zoomable_widget`: add `enableRotate`.

## [0.3.13]

- Add `autoCenter` in `zoomable_widget`.
- Check the widget mount state `TransitionToImage`.

## [0.3.12]

- Add `onZoomStateChanged` callback in `zoomable_widget`.

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
