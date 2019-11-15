(define-module (custom-garbage bashBugged)
  #:use-module (guix licenses)
  #:use-module (gnu packages)
  #:use-module (gnu packages bootstrap)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages readline)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages linux)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix gexp)
  #:use-module (guix monads)
  #:use-module (guix store)
  #:use-module (guix build-system gnu)
  #:autoload   (guix gnupg) (gnupg-verify*)
  #:autoload   (gcrypt hash) (port-sha256)
  #:autoload   (guix base32) (bytevector->nix-base32-string)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (ice-9 format))

(define-public bashBugged
  (let* ((cppflags (string-join '("-DDEFAULT_PATH_VALUE='\"/no-such-path\"'"
                                  "-DSTANDARD_UTILS_PATH='\"/no-such-path\"'"
                                  "-DNON_INTERACTIVE_LOGIN_SHELLS"
                                  "-DSSH_SOURCE_BASHRC")
                                " "))
         (configure-flags
          ``("--with-installed-readline"
             ,,(string-append "CPPFLAGS=" cppflags)
             ,(string-append
               "LDFLAGS=-Wl,-rpath -Wl,"
               (assoc-ref %build-inputs "readline")
               "/lib"
               " -Wl,-rpath -Wl,"
               (assoc-ref %build-inputs "ncurses")
               "/lib")))
         (version "5.0"))
    (package
     (name "bashBugged")
     (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://gnu/bash/bash-" version ".tar.gz"))
              (sha256
               (base32
                "0kgvfwqdcd90waczf4gx39xnrxzijhjrzyzv7s8v4w31qqm0za5l"))
              (patch-flags '("-p0"))
              (patches (search-patches "bashBugged.patch"))))
     (version "555")
     (build-system gnu-build-system)

     (outputs '("out"
                "doc"                         ;1.7 MiB of HTML and extra files
                "include"))                   ;headers used by extensions
     (inputs `(("readline" ,readline)
               ("ncurses" ,ncurses)))             ;TODO: add texinfo
     (arguments
      `(;; When cross-compiling, `configure' incorrectly guesses that job
        ;; control is missing.
        #:configure-flags ,(if (%current-target-system)
                               `(cons* "bash_cv_job_control_missing=no"
                                       ,configure-flags)
                               configure-flags)

			  ;; Bash is reportedly not parallel-safe.  See, for instance,
			  ;; <http://patches.openembedded.org/patch/32745/> and
			  ;; <http://git.buildroot.net/buildroot/commit/?h=79e2d802a>.
			  #:parallel-build? #f
			  #:parallel-tests? #f

			  ;; XXX: The tests have a lot of hard-coded paths, so disable them
			  ;; for now.
			  #:tests? #f

			  #:modules ((srfi srfi-26)
				     (guix build utils)
				     (guix build gnu-build-system))

			  #:phases
			  (modify-phases %standard-phases
					 (add-after 'install 'install-sh-symlink
						    (lambda* (#:key outputs #:allow-other-keys)
						      ;; Add a `sh' -> `bash' link.
						      (let ((out (assoc-ref outputs "out")))
							(with-directory-excursion (string-append out "/bin")
										  (symlink "bash" "sh")
										  #t))))

					 (add-after 'install 'move-development-files
						    (lambda* (#:key outputs #:allow-other-keys)
						      ;; Move 'Makefile.inc' and 'bash.pc' to "include" to avoid
						      ;; circular references among the outputs.
						      (let ((out     (assoc-ref outputs "out"))
							    (include (assoc-ref outputs "include"))
							    (lib     (cut string-append <> "/lib/bash")))
							(mkdir-p (lib include))
							(rename-file (string-append (lib out)
										    "/Makefile.inc")
								     (string-append (lib include)
										    "/Makefile.inc"))
							(rename-file (string-append out "/lib/pkgconfig")
								     (string-append include
										    "/lib/pkgconfig"))

							;; Don't capture the absolute file name of 'install' to avoid
							;; retaining a dependency on Coreutils.
							(substitute* (string-append (lib include)
										    "/Makefile.inc")
								     (("^INSTALL =.*")
								      "INSTALL = install -c\n"))
							#t))))))

     (native-search-paths
      (list (search-path-specification            ;new in 4.4
             (variable "BASH_LOADABLES_PATH")
             (files '("lib/bash")))))

     (synopsis "The GNU Bourne-Again SHell")
     (description
      "Bash is the shell, or command-line interpreter, of the GNU system.  It
is compatible with the Bourne Shell, but it also integrates useful features
from the Korn Shell and the C Shell and new improvements of its own.  It
allows command-line editing, unlimited command history, shell functions and
aliases, and job control while still allowing most sh scripts to be run
without modification.")
     (license gpl3+)
     (home-page "https://www.gnu.org/software/bash/"))))
