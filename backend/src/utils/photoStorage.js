const fs     = require('fs');
const path   = require('path');
const crypto = require('crypto');
const multer = require('multer');
const config   = require('../config/env');
const AppError = require('./AppError');

// Profile photos : files in UPLOADS_DIR/photos, served at /api/uploads/photos/<name> (see app.js).
// The name is random : a photo can't be found by guessing a user id.

const PHOTOS_DIR = path.join(config.uploadsDir, 'photos');

/** The app resizes the photo (512 px) before sending it : 2 MB is plenty. */
const MAX_PHOTO_SIZE = 2 * 1024 * 1024;

const EXTENSIONS = { 'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp' };

/** First bytes of each accepted format : the type sent by the client is not trusted alone. */
const SIGNATURES = [
  (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff,                                    // JPEG
  (b) => b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])), // PNG
  (b) => b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP',      // WebP
];

/** Multer middleware : the file of the `photo` field is saved in PHOTOS_DIR (req.file). */
const uploadPhoto = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => fs.mkdir(PHOTOS_DIR, { recursive: true }, (err) => cb(err, PHOTOS_DIR)),
    filename   : (req, file, cb) => cb(null, `${req.user.id}-${crypto.randomUUID()}${EXTENSIONS[file.mimetype]}`),
  }),
  limits    : { fileSize: MAX_PHOTO_SIZE, files: 1 },
  fileFilter: (req, file, cb) => {
    if (!EXTENSIONS[file.mimetype]) { return cb(AppError.badRequest('INVALID_IMAGE', 'The photo must be a JPEG, PNG or WebP image')); }
    cb(null, true);
  },
}).single('photo');

/** Deletes a photo file, if there is one (a missing file is not an error). */
const removePhoto = async (name) => {
  if (!name) return;
  await fs.promises.rm(path.join(PHOTOS_DIR, path.basename(name)), { force: true });
};

/** Checks that the uploaded file really is an image, deletes it if not. */
const checkPhoto = async (file) => {
  const handle = await fs.promises.open(file.path, 'r');
  const { buffer } = await handle.read(Buffer.alloc(12), 0, 12, 0);
  await handle.close();

  if (!SIGNATURES.some((matches) => matches(buffer))) {
    await removePhoto(file.filename);
    throw AppError.badRequest('INVALID_IMAGE', 'The photo must be a JPEG, PNG or WebP image');
  }
};

module.exports = { PHOTOS_DIR, MAX_PHOTO_SIZE, uploadPhoto, removePhoto, checkPhoto };
