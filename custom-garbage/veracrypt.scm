(define-module (custom-garbage veracrypt)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build utils)
  #:use-module (guix utils)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages assembly)
  #:use-module (gnu packages wxwidgets)
  #:use-module (gnu packages linux)
  #:use-module ((srfi srfi-1) #:hide (zip))
  #:use-module (srfi srfi-26)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 match)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-19)
  #:use-module (srfi srfi-34)
  #:use-module (srfi srfi-35)
  #:use-module (srfi srfi-26)
  #:use-module (rnrs io ports))

(define-public veracrypt
  (package
   (name "veracrypt")
   (version "1.24-Hotfix1")
   (source (origin
	    (method url-fetch)
	    (uri "https://launchpad.net/veracrypt/trunk/1.24-hotfix1/+download/VeraCrypt_1.24-Hotfix1_Source.zip")
	    (sha256
	     (base32
	      "1asy066wy7xdxlj562s70m4rlsak0cg4yjdrpmgnyxn767dz1dni"))))
   (native-inputs `(("fuse" ,fuse)
		    ("pkg-config" ,pkg-config)
		    ("yasm" ,yasm)
		    ("unzip" ,unzip)
		    ("wxwidgets" ,wxwidgets)))
   (build-system gnu-build-system)
   (arguments
    '(#:make-flags '("CC=gcc")
      
      #:phases
      (modify-phases %standard-phases
	(delete 'configure)
	(delete 'check)
	(replace 'unpack
	  (lambda* (#:key source #:allow-other-keys)
	    (invoke "unzip" source)
	    (chdir "src")))
	(replace 'install
	  (lambda* (#:key outputs #:allow-other-keys)
	    (let* ((out (assoc-ref outputs "out"))
		   (bin (string-append out "/bin")))
	      (chdir "Main")
	      (install-file "veracrypt" bin)) #t)))))
   (synopsis "VeraCrypt is a free open source disk encryption software for Windows, Mac OSX and Linux. Brought to you by IDRIX (https://www.idrix.fr) and based on TrueCrypt 7.1a.")
   (description
    "VeraCrypt main features:

    Creates a virtual encrypted disk within a file and mounts it as a real disk.
    Encrypts an entire partition or storage device such as USB flash drive or hard drive.
    Encrypts a partition or drive where Windows is installed (pre-boot authentication).
    Encryption is automatic, real-time(on-the-fly) and transparent.
    Parallelization and pipelining allow data to be read and written as fast as if the drive was not encrypted.
    Encryption can be hardware-accelerated on modern processors.
    Provides plausible deniability, in case an adversary forces you to reveal the password: Hidden volume (steganography) and hidden operating system.
    More information about the features of VeraCrypt may be found in the documentation")
   
   (license (license:non-copyleft "file://License.txt" "See \"License.txt\" in the distribution"))
   
   (home-page "https://www.veracrypt.fr")))
