require './lib/event-move';
require './lib/event-swipe';
require './lib/keymaster';

GalleryView = require './views/gallery';
GalleryPhotoView = require './views/gallery_photo';

module.exports = {
    GalleryView: GalleryView,
    GalleryPhotoView: GalleryPhotoView,
};
