;;; php-styles.el --- Better support for multiple coding styles for php/mode.el

;;; License

;; This file is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
;; 02110-1301, USA.

;;; Commentary:

;; PHP mode does not provide an easy way to switch to a different
;; coding style, which makes it a pain to edit multiple files in
;; different types of projects in a single Emacs session.  This
;; package provide some helper functions to do it.

;;; Usage:

;; To enable this package, add the php-styles-php-mode-config
;; function to php-mode-hook :

;;   (add-hook 'php-mode-hook 'php-styles-mode-config)

;; You will then be able to use the
;; php-styles-switch-to-wordpress and php-styles-switch-to-spip
;; commands.

;; We will try to guess the coding style by searching for a
;; common file. You can disable this feature using the
;; php-style-guess customizable variable.

;;; Code:

(require 'php-mode)
(require 'flycheck)

(add-to-list 'load-path (file-name-directory load-file-name))

(defgroup php-styles nil
  "Coding styles management for PHP."
  :group 'php)

(defcustom php-styles-guess t
  "If not true, disable the automatic style selection.")

(defcustom php-styles-names '("psr-2" "spip" "wordpress")
  "A list of strings representing coding style names.

For each coding styles, we will look for a
php-styles-configure-STRING function, where STRING is the coding
style's name.  This function will be executed in the
php-styles-php-mode-config function if the corresponding style is
active.

The automatic style guessing system will look for a variable
named php-styles-clue-STRING, and search for a file that has this
name in the current file's parent directories.  If this file
exists in a parent directory, the corresponding style will be
used.

Also, each style name will automatically get an interactive
function that allows to change the current editing style to it.")

(defcustom php-styles-default-style "psr-2"
  "The default style used for PHP-mode.")

(defun php-styles-configure-psr-2 ()
  "Configure php-mode to use the PSR-2 style."

  (custom-set-variables '(php-mode-coding-style "PSR-2")
                        '(phpcbf-standard "PSR-2"))
  (setq flycheck-phpcs-standard "PSR2"))

(defun php-styles-configure-spip ()
  "Configure php-mode for SPIP.
Use PSR-2, but indent with tabs and configure flycheck and phpcbf
to use SPIP's coding style."

  (custom-set-variables '(php-mode-coding-style "PSR-2")
                        '(phpcbf-standard (locate-file "phpcs-SPIP.xml" load-path)))
  (setq indent-tabs-mode t
        flycheck-phpcs-standard (locate-file "phpcs-SPIP.xml" load-path)))

(defun php-styles-configure-wordpress ()
  "Configure php-mode for Wordpress."

  (custom-set-variables '(php-mode-coding-style "WordPress")
                        '(phpcbf-standard "WordPress"))
  (php-enable-wordpress-coding-style)
  (setq flycheck-phpcs-standard "WordPress"))

(defvar php-styles-clue-spip "spip.php")
(defvar php-styles-clue-wordpress "wp-login.php")

(defvar php-styles-style php-styles-default-style)
(defvar php-styles-override-guess nil)

(defun php-styles-php-mode-config ()
  "Configure php-mode to use the active style.
Add this function to php-mode-hook."

  (if (and (not php-styles-override-guess)
           php-styles-guess)
      (php-styles-guess-styles))

  (catch 'conf-done
    (mapc (lambda (style-name)
            (let*
                ((conf-func-name (concat "php-styles-configure-" style-name))
                 (conf-func (intern-soft conf-func-name)))

              (if (and (equal php-styles-style style-name)
                       (functionp conf-func))
                  (progn
                    (funcall (symbol-function conf-func))
                    (throw 'conf-done nil)))))
          php-styles-names))

  (setq php-styles-override-guess nil))

(defun php-styles-guess-styles ()
  "Guess the kind of project the current file belongs to."

  (if (equal php-styles-names
       (catch 'guess-found
         (mapc (lambda (style-name)
                 (let* ((clue-symbol (concat
                                      "php-styles-clue-" style-name))
                        (clue (symbol-value
                               (intern-soft clue-symbol))))

                   (if (and (stringp clue)
                            (find-file-in-parent-directories clue))
                       (progn
                         (setq php-styles-style style-name)
                         (throw 'guess-found t)))))
               php-styles-names)))
      (setq php-styles-style php-styles-default-style)))

(defmacro php-styles-defun-switch-function (style-name)
  "Defines an interactive function that switch to STYLE-NAME."
  `(defun ,(intern (format "php-styles-switch-to-%s" style-name))
       ()
     ,(format "Switch to %s coding style." style-name)
     (interactive)
     (setq php-styles-override-guess t)
     (setq php-styles-style ,style-name)
     (php-mode)))

;; I don't why this doesn't work...
;; (mapc (lambda (style-name)
;;         (php-styles-defun-switch-function style-name))
;;       php-styles-names)

;; ...but this does
(php-styles-defun-switch-function "psr-2")
(php-styles-defun-switch-function "spip")
(php-styles-defun-switch-function "wordpress")

(defun find-file-in-parent-directories (clue-filename)
  "Check if a file called CLUE-FILENAME exists in a parent directory."

  (let ((path (expand-file-name default-directory))
        (result nil))

    (while (not (equal path "/"))
      (if (file-exists-p (concat path "/" clue-filename))
          (setq path "/"
                result t)
        (setq path (dir-up path))))

    result))

(defun dir-up (dirname)
  "Return the name of DIRNAME's parent directory."

  (concat
   (mapconcat 'identity
              (reverse (cddr (reverse
                              (split-string dirname "/"))))
              "/")
   "/"))

(provide 'php-styles)
;;; php-styles.el ends here
