;; SPDX-License-Identifier: GPL-3.0
;;; licensel.el --- Insert license templates -*- lexical-binding: t; -*-

;; Author: Lucas Poupeau
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: tools
;; URL: https://github.com/dkdwn/licensel

;;; Commentary:

;; Insert license templates into the current buffer.

;;; Code:

(require 'seq)

(defgroup licensel nil
  "Insert license templates."
  :group 'tools)

(defcustom licensel-directory
  (expand-file-name
   "licenses"
   (file-name-directory
    (or load-file-name
        (locate-library "licensel")
        buffer-file-name
        default-directory)))
  "Directory containing license templates."
  :type 'directory
  :group 'licensel)

;;;###autoload
(defun licensel-insert ()
  "Select a license and insert its content into the current buffer."
  (interactive)
  (unless (file-directory-p licensel-directory)
    (user-error "License directory not found: %s" licensel-directory))

  (let* ((licenses
          (seq-filter
           (lambda (file)
             (file-regular-p
              (expand-file-name file licensel-directory)))
           (directory-files licensel-directory nil "^[^.]")))
         (selected
          (completing-read "License: " licenses nil t)))

    (when (string-empty-p selected)
      (user-error "No license selected"))

    (insert-file-contents
     (expand-file-name selected licensel-directory))))

(provide 'licensel)

;;; licensel.el ends here
