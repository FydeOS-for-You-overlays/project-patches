# Copyright (c) 2012 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7
CROS_WORKON_COMMIT="127c5e645a90adbfca7f7a080ace19d9b992eee4"
CROS_WORKON_TREE="8de3bf11a8040efbd53dd06a2bc7cc7af01eed50"
CROS_WORKON_PROJECT="chromiumos/platform/vpd"

inherit cros-workon systemd

DESCRIPTION="ChromeOS vital product data utilities"
HOMEPAGE="http://www.chromium.org/"
SRC_URI=""

LICENSE="BSD-Google"
KEYWORDS="*"
IUSE="static systemd"

# util-linux is for libuuid.
DEPEND="sys-apps/util-linux:="
# shflags for dump_vpd_log.
# chromeos-activate-date for ActivateDate upstart and script.
RDEPEND="
	sys-apps/flashrom
	dev-util/shflags
	virtual/chromeos-activate-date
	"

FYDEOS_DEFAULT_LOCALE="zh-CN"
FYDEOS_DEFAULT_TIMEZONE="Asia/Shanghai"
FYDEOS_DEFAULT_REGION="zh_CN"
VPD_TEMPLATE="oem_licence.tmp"

src_prepare() {
  default
  epatch ${FILESDIR}/*.patch
  cp ${FILESDIR}/${VPD_TEMPLATE} ${S}
}

count_chars() {
  printf $1 | wc -c
}

src_configure() {
	cros-workon_src_configure
}

src_compile() {
	tc-export CC
	use static && append-ldflags -static
	emake all
  local locale=${FYDEOS_LOCALE:-`echo $FYDEOS_DEFAULT_LOCALE`}
  local timezone=${FYDEOS_TIMEZONE:-`echo $FYDEOS_DEFAULT_TIMEZONE`}
  local region=${FYDEOS_REGION:-`echo $FYDEOS_DEFAULT_REGION`}
  ${FILESDIR}/vpd -i RO_VPD -f ${VPD_TEMPLATE} \
    -p $(count_chars $locale) -s "initial_locale=${locale}" \
    -p $(count_chars $timezone) -s "initial_timezone=${timezone}" \
    -p $(count_chars $region) -s "region=${region}"
  cat ${VPD_TEMPLATE} | gzip > "vpd.gz"
}

src_install() {
	# This target list should be architecture specific
	# (no ACPI stuff on ARM for instance)
	dosbin vpd vpd_s
	dosbin util/check_rw_vpd util/dump_vpd_log util/update_rw_vpd
	dosbin util/vpd_get_value

	# install the init script
	if use systemd; then
		systemd_dounit init/vpd-log.service
		systemd_enable_service boot-services.target vpd-log.service
	else
		insinto /etc/init
		doins init/check-rw-vpd.conf
		doins init/vpd-log.conf
    doins ${FILESDIR}/check_serial_number.conf
	fi
  insinto /usr/share/cros/init
  doins vpd.gz
  doins ${FILESDIR}/check_serial_number.sh
}

src_test() {
	if ! use x86 && ! use amd64; then
		ewarn "Skipping unittests for non-x86 arches"
		return
	fi
	emake test
}
