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

(defcustom licensel-placeholders
  '("<YEAR>" "<year>" "[year]" "[yyyy]" "YEAR"
    "<COPYRIGHT HOLDER>" "<owner>" "[copyright holders]" "AUTHOR EMAIL")
  "Placeholders to jump to after inserting a license.
They are matched literally and case-sensitively."
  :type '(repeat string)
  :group 'licensel)

(defcustom licensel-placeholder-lines 5
  "Number of lines at the top of the license searched for placeholders.
Placeholders further down, such as the \"How to apply\" appendix of
the GPL or Apache licenses, are part of the license text itself and
are left alone."
  :type 'integer
  :group 'licensel)

(defface licensel-placeholder
  '((t :inherit highlight))
  "Face for placeholders waiting to be filled."
  :group 'licensel)

(defvar licensel--replacing-commands
  '(self-insert-command yank clipboard-yank)
  "Commands that replace a placeholder when run at its start.")

(defvar-local licensel--fields nil
  "Overlays of the placeholders of the last inserted license.")

(defvar-local licensel--index 0
  "Index of the current field in `licensel--fields'.")

(defvar licensel-fields-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'licensel-next-field)
    (define-key map (kbd "<backtab>") #'licensel-previous-field)
    (define-key map (kbd "C-c C-c") #'licensel-finish)
    map)
  "Keymap active while filling the placeholders of a license.")

(define-minor-mode licensel-fields-mode
  "Navigate the placeholders of a freshly inserted license.
Typing at the start of a placeholder replaces it.  The mode ends
after the last field, with \\[licensel-finish], or when point
leaves the fields.

\\{licensel-fields-mode-map}"
  :lighter " Licensel"
  :group 'licensel
  (if licensel-fields-mode
      (progn
        (add-hook 'pre-command-hook #'licensel--pre-command nil t)
        (add-hook 'post-command-hook #'licensel--post-command nil t))
    (remove-hook 'pre-command-hook #'licensel--pre-command t)
    (remove-hook 'post-command-hook #'licensel--post-command t)
    (mapc #'delete-overlay licensel--fields)
    (setq licensel--fields nil
          licensel--index 0)))

(defun licensel--collect-fields (beg end)
  "Return overlays on the placeholders found between BEG and END.
Only the first `licensel-placeholder-lines' lines are searched."
  (when licensel-placeholders
    (let ((regexp (mapconcat #'regexp-quote licensel-placeholders "\\|"))
          (case-fold-search nil)
          fields)
      (save-excursion
        (goto-char beg)
        (let ((bound (save-excursion
                       (forward-line licensel-placeholder-lines)
                       (min (point) end))))
          (while (re-search-forward regexp bound t)
            (let ((ov (make-overlay (match-beginning 0) (match-end 0)
                                    nil nil t)))
              (overlay-put ov 'face 'licensel-placeholder)
              (overlay-put ov 'licensel-pristine t)
              (push ov fields)))))
      (nreverse fields))))

(defun licensel--goto-field (index)
  "Move point to the start of field number INDEX."
  (setq licensel--index index)
  (goto-char (overlay-start (nth index licensel--fields))))

(defun licensel--pre-command ()
  "Delete the current placeholder when the user starts typing over it."
  (let ((ov (nth licensel--index licensel--fields)))
    (when (and ov
               (overlay-get ov 'licensel-pristine)
               (= (point) (overlay-start ov))
               (memq this-command licensel--replacing-commands))
      (overlay-put ov 'licensel-pristine nil)
      (delete-region (overlay-start ov) (overlay-end ov)))))

(defun licensel--post-command ()
  "End `licensel-fields-mode' when point is outside every field."
  (unless (seq-some (lambda (ov)
                      (<= (overlay-start ov) (point) (overlay-end ov)))
                    licensel--fields)
    (licensel-fields-mode -1)))

(defun licensel-next-field ()
  "Move to the next placeholder, or finish after the last one."
  (interactive)
  (if (< (1+ licensel--index) (length licensel--fields))
      (licensel--goto-field (1+ licensel--index))
    (licensel-finish)))

(defun licensel-previous-field ()
  "Move to the previous placeholder."
  (interactive)
  (when (> licensel--index 0)
    (licensel--goto-field (1- licensel--index))))

(defun licensel-finish ()
  "Stop navigating the placeholders of the inserted license."
  (interactive)
  (licensel-fields-mode -1))

;;;###autoload
(defun licensel-insert ()
  "Select a license and insert its content into the current buffer.
Point then jumps to the first placeholder (year, copyright holder)
and `licensel-fields-mode' lets you move between them with TAB."
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

    (let* ((beg (point))
           (end (+ beg (cadr (insert-file-contents
                              (expand-file-name selected licensel-directory)))))
           (fields (licensel--collect-fields beg end)))
      (when fields
        (when licensel-fields-mode
          (licensel-fields-mode -1))
        (setq licensel--fields fields)
        (licensel-fields-mode 1)
        (licensel--goto-field 0)
        (message "TAB: next field, S-TAB: previous, C-c C-c: done")))))

(provide 'licensel)

;;; licensel.el ends here
