;;; dataflow-diagram.el --- A major mode for dataflow diagrams -*- lexical-binding: t -*-

;; Copyright (C) 2021 Akira Komamura

;; Author: Akira Komamura <akira.komamura@gmail.com>
;; Version: 0.1
;; Package-Requires: ((emacs "26.1"))
;; Keywords: tools
;; URL: https://github.com/akirak/dataflow-diagram-mode

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This library provides `dataflow-diagram-mode', which is a major mode for
;; editing source files of dataflow:
;; <https://github.com/sonyxperiadev/dataflow>.

;;; Code:

(defgroup dataflow-diagram nil
  "Major mode for editing dataflow diagrams."
  :group 'tools)

(defcustom dataflow-diagram-executable "dataflow"
  "Path to the executable of dataflow."
  :type 'file
  :group 'dataflow-diagram)

(defvar dataflow-diagram-font-lock-keywords
  `(("\\(?:boundary\\|database\\|function\\|io\\)[[:space:]]+\\([A-Za-z][0-9A-Z_a-z]*\\)"
     (1 font-lock-function-name-face))
    ("\\([A-Za-z][0-9A-Z_a-z]+\\)[[:space:]]+\\(?:->\\|<-\\)"
     (1 font-lock-function-name-face))
    ("\\(?:->\\|<-\\)[[:space:]]+\\([A-Za-z][0-9A-Z_a-z]+\\)"
     (1 font-lock-function-name-face))
    ("\\([A-Za-z][0-9A-Z_a-z]+\\)[[:space:]]+=[[:space:]]+"
     (1 font-lock-variable-name-face))
    (,(regexp-opt '("diagram") 'words)
     (0 font-lock-keyword-face))
    (,(regexp-opt '("diagram" "boundary" "database" "function" "io") 'words)
     (0 font-lock-type-face))))

(defvar dataflow-diagram-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?\  " " table)
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\` "\"" table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?, "." table)
    (modify-syntax-entry ?< "_" table)
    (modify-syntax-entry ?- "_" table)
    (modify-syntax-entry ?> "_" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\/ ". 14" table)
    (modify-syntax-entry ?\* ". 23" table)
    table)
  "Syntax table for `dataflow-diagram-mode'.")

(defcustom dataflow-diagram-indent-offset 2
  "Indent offset in `dataflow-diagram-mode'."
  :type 'number)

(defun dataflow-diagram--empty-line-p ()
  "Return non-nil if the current line contain only spaces."
  (save-excursion
    (beginning-of-line 1)
    (looking-at (rx (* space) eol))))

(defun dataflow-diagram--indent-level ()
  "Return the desired indentation level at point."
  (let ((ppss (syntax-ppss)))
    (cond
     ;; Inside a comment or backtick pair
     ((or (nth 4 ppss)
          (and (nth 3 ppss) (= ?\` (nth 3 ppss))))
      (let ((string-start (nth 8 ppss)))
        (if (looking-at (rx (* space) "*/"))
            (save-excursion
              (goto-char string-start)
              (current-indentation))
          (save-excursion
            (if (> (point) string-start)
                (back-to-indentation)
              (goto-char string-start)
              (re-search-forward (rx (or "`" "/*")))
              (unless (eolp)
                (re-search-forward (rx (* space)))))
            (car (posn-col-row (posn-at-point (point))))))))
     ;; Top-level
     ((= 0 (nth 0 ppss))
      0)
     ((dataflow-diagram--empty-line-p)
      0)
     ;; The first item inside a block
     ((looking-back (rx "{" (* space)) (nth 1 ppss))
      (let ((prev-indent (save-excursion
                           (goto-char (nth 1 ppss))
                           (current-indentation))))
        (if (looking-at (rx (* space) "}"))
            (indent-line-to prev-indent)
          (+ prev-indent dataflow-diagram-indent-offset))))
     ;; Before the close of a block
     ((looking-at (rx (* space) "}"))
      (save-excursion
        (goto-char (nth 1 ppss))
        (current-indentation)))
     (t
      (save-excursion
        (goto-char (nth 1 ppss))
        (down-list)
        (re-search-forward (rx (* space)))
        (current-indentation))))))

(defun dataflow-diagram--delete-space-after-point ()
  "Delete space after the point."
  (when (looking-at (rx (+ space)))
    (let ((start (point)))
      (re-search-forward (rx (* space)))
      (delete-region start (point)))))

(defun dataflow-diagram--indent-line ()
  "Indent the current line but don't restore the point."
  (back-to-indentation)
  (indent-line-to (dataflow-diagram--indent-level))
  (dataflow-diagram--delete-space-after-point))

(defun dataflow-diagram-indent-line ()
  "Indent the current line in `dataflow-diagram-mode'."
  (interactive)
  (if (looking-back (rx bol (* space)) (line-beginning-position))
      (dataflow-diagram--indent-line)
    (save-excursion
      (dataflow-diagram--indent-line))))

(define-derived-mode dataflow-diagram-mode prog-mode "Dataflow"
  "Major mode for dataflow."
  :group 'dataflow-diagram
  (setq-local font-lock-defaults '(dataflow-diagram-font-lock-keywords))
  (setq-local indent-line-function #'dataflow-diagram-indent-line)
  (run-hooks 'dataflow-diagram-mode-hook))

(provide 'dataflow-diagram)
;;; dataflow-diagram.el ends here
