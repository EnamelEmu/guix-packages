;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2013, 2014 Andreas Enge <andreas@enge.fr>
;;; Copyright © 2014, 2015, 2016 Mark H Weaver <mhw@netris.org>
;;; Copyright © 2015, 2016, 2018 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2016, 2019 Leo Famulari <leo@famulari.name>
;;; Copyright © 2016 Nicolas Goaziou <mail@nicolasgoaziou.fr>
;;; Copyright © 2016 Christopher Allan Webber <cwebber@dustycloud.org>
;;; Copyright © 2017, 2018, 2019 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2017 Stefan Reichör <stefan@xsteve.at>
;;; Copyright © 2017 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2017 ng0 <ng0@n0.is>
;;; Copyright © 2018 Manuel Graf <graf@init.at>
;;; Copyright © 2019 Gábor Boskovits <boskovits@gmail.com>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (custom-garbage ossh)
  #:use-module (gnu packages)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:autoload   (gnu packages boost) (boost)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages crypto)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages gperf)
  #:use-module (gnu packages groff)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages libedit)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages logging)
  #:use-module (gnu packages m4)
  #:use-module (gnu packages multiprecision)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages nettle)
  #:use-module (gnu packages kerberos)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages popt)
  #:autoload   (gnu packages protobuf) (protobuf)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages readline)
  #:use-module (gnu packages texinfo)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages xorg)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system python)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (srfi srfi-1))

(define-public openssh-test
  (package
   (name "openssh-test")
   (version "8.0p1")
   (source (origin
             (method url-fetch)
             (uri (string-append "mirror://openbsd/OpenSSH/portable/"
                                 "openssh-" version ".tar.gz"))
             (sha256
              (base32
               "0s7xh4s0qcipnjh9ls5blxcpvhyd116z9dxn3q1yi64lwrwki55x"))
	     (patches (list (search-patch "openssh.patch")))))
   (build-system gnu-build-system)
   (native-inputs `(("groff" ,groff)
                    ("pkg-config" ,pkg-config)))
   (inputs `(("libedit" ,libedit)
             ("openssl" ,openssl)
             ("pam" ,linux-pam)
             ("mit-krb5" ,mit-krb5)
             ("zlib" ,zlib)
             ("xauth" ,xauth)))                   ;for 'ssh -X' and 'ssh -Y'
   (arguments
    `(#:test-target "tests"
      ;; Otherwise, the test scripts try to use a nonexistent directory and
      ;; fail.
      #:make-flags '("REGRESSTMP=\"$${BUILDDIR}/regress\"")
      #:configure-flags  `("--sysconfdir=/etc/ssh"

                           ;; Default value of 'PATH' used by sshd.
                          "--with-default-path=/run/current-system/profile/bin"

                          ;; configure needs to find krb5-config
                          ,(string-append "--with-kerberos5="
                                          (assoc-ref %build-inputs "mit-krb5")
                                          "/bin")

                          ;; libedit needed for sftp completion
                          "--with-libedit"

                          ;; Enable PAM support in sshd.
                          "--with-pam")

      #:phases
      (modify-phases %standard-phases
        (add-after 'configure 'reset-/var/empty
         (lambda* (#:key outputs #:allow-other-keys)
           (let ((out (assoc-ref outputs "out")))
             (substitute* "Makefile"
               (("PRIVSEP_PATH=/var/empty")
                (string-append "PRIVSEP_PATH=" out "/var/empty")))
             #t)))
        (add-before 'check 'patch-tests
         (lambda _
           ;; remove 't-exec' regress target which requires user 'sshd'
           (substitute* "regress/Makefile"
             (("^(REGRESS_TARGETS=.*) t-exec(.*)" all pre post)
              (string-append pre post)))
           #t))
        (replace 'install
         (lambda* (#:key outputs (make-flags '()) #:allow-other-keys)
           ;; install without host keys and system configuration files
           (apply invoke "make" "install-nosysconf" make-flags)
           (install-file "contrib/ssh-copy-id"
                         (string-append (assoc-ref outputs "out")
                                        "/bin/"))
           (chmod (string-append (assoc-ref outputs "out")
                                 "/bin/ssh-copy-id") #o555)
           (install-file "contrib/ssh-copy-id.1"
                         (string-append (assoc-ref outputs "out")
                                        "/share/man/man1/"))
           #t)))))
   (synopsis "Client and server for the secure shell (ssh) protocol")
   (description
    "The SSH2 protocol implemented in OpenSSH is standardised by the
IETF secsh working group and is specified in several RFCs and drafts.
It is composed of three layered components:

The transport layer provides algorithm negotiation and a key exchange.
The key exchange includes server authentication and results in a
cryptographically secured connection: it provides integrity, confidentiality
and optional compression.

The user authentication layer uses the established connection and relies on
the services provided by the transport layer.  It provides several mechanisms
for user authentication.  These include traditional password authentication
as well as public-key or host-based authentication mechanisms.

The connection layer multiplexes many different concurrent channels over the
authenticated connection and allows tunneling of login sessions and
TCP-forwarding.  It provides a flow control service for these channels.
Additionally, various channel-specific options can be negotiated.")
   (license (license:non-copyleft "file://LICENSE"
                               "See LICENSE in the distribution."))
   (home-page "https://www.openssh.com/")))
