#!/bin/bash -e
# SPDX-License-Identifier: BSD-3-Clause
# Copyright(c) 2018 Intel Corporation. All rights reserved.


TOPDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Used only by more advanced error handling
source_opt_libsh()
{
    local libsh="$TOPDIR"/case-lib/lib.sh
    if test -e "$libsh"; then
        # shellcheck source=case-lib/lib.sh
        source "$libsh"
    fi
}

remove_module() {

    local MODULE="$1"

    if grep -q "^${MODULE}[[:blank:]]" /proc/modules; then
        printf 'RMMOD\t%s\n' "$MODULE"
        sudo rmmod "$MODULE"
    else
        printf 'SKIP\t%s  \tnot loaded\n' "$MODULE"
    fi
}

exit_handler()
{
    local exit_status="$1"
    # Even without any active audio, pulseaudio can use modules
    # "non-deterministically". So even if we are successful this time,
    # warn about any running pulseaudio because it could make us fail
    # the next time.
    # TODO: display any pipewire process too.
    if pgrep -a pulseaudio; then
        systemctl_show_pulseaudio || true
    fi

    if test "$exit_status" -ne 0; then
        lsmod | grep -e sof -e snd -e sound -e drm
        # rmmod can fail silently, for instance when "Used by" is -1
        printf "%s FAILED\n" "$0"
    fi

    return "$exit_status"
}

# Always return 0 because if a lingering sof-logger is an error, it's
# not _our_ error.
kill_trace_users()
{
    local dma_trace=/sys/kernel/debug/sof/trace

    sudo fuser "$dma_trace" || return 0

    ( set -x
      sudo fuser --kill -TERM "$dma_trace" || true
      sudo fuser "$dma_trace" || return 0
      sleep 1
      sudo fuser --kill -KILL "$dma_trace" || true
    )
}

source_opt_libsh
trap 'exit_handler $?' EXIT

# Breaks systemctl --user and "double sudo" is not great
test "$(id -u)" -ne 0 ||
    >&2 printf '\nWARNING: running as root is not supported\n\n'

# Make sure sudo works first, not after dozens of SKIP
sudo true

# For some reason (bug?) using /sys/kernel/debug/sof/trace hangs rmmod
# Playing audio is not an issue, for instance speaker-test -s 1 -l 0 is
# interrupted when unloading the drivers.
kill_trace_users

# SOF CI has a dependency on usb audio
remove_module snd_usb_audio
remove_module snd_usbmidi_lib

#-------------------------------------------
# Top level devices
# ACPI is after PCI due to TNG dependencies
# TGL and ICL depend on CNL, PTL on LNL and
# LNL on MTL, the non-linear order is
# intentional
#-------------------------------------------
remove_module snd_hda_intel
remove_module snd_sof_pci_intel_tng
remove_module snd_sof_pci_intel_skl
remove_module snd_sof_pci_intel_apl

remove_module snd_sof_pci_intel_tgl
remove_module snd_sof_pci_intel_icl
remove_module snd_sof_pci_intel_cnl

remove_module snd_sof_pci_intel_ptl
remove_module snd_sof_pci_intel_lnl
remove_module snd_sof_pci_intel_mtl

remove_module snd_sof_acpi_intel_byt
remove_module snd_sof_acpi_intel_bdw

#-------------------------------------------
# Top level devices
# i.MX-specific drivers
#-------------------------------------------
remove_module snd_sof_imx8
remove_module snd_sof_imx8m

#-------------------------------------------
# legacy drivers (not used but loaded)
#-------------------------------------------
remove_module snd_soc_catpt
remove_module snd_intel_sst_acpi
remove_module snd_intel_sst_core
remove_module snd_soc_sst_atom_hifi2_platform
remove_module snd_soc_skl

#-------------------------------------------
# AVS drivers (not used but loaded)
#-------------------------------------------
remove_module snd_soc_avs
remove_module snd_soc_hda_codec

#-------------------------------------------
# platform drivers
#-------------------------------------------
remove_module snd_sof_intel_hda_generic
# Attempt 1/2
#
# - In the SDW BRA future this will be "in use by
#   snd_sof_intel_hda_sdw_bpt" and will fail.  Ignore that failure.
# - In the 6.5-ish "present" 'soundwire_intel' depends on it so it must
#   be removed first.
# https://github.com/thesofproject/sof-test/pull/1182
remove_module snd_sof_intel_hda_common || true

#-------------------------------------------
# SoundWire/SOF parts
#-------------------------------------------
remove_module soundwire_intel_init
remove_module soundwire_intel
remove_module soundwire_cadence
remove_module soundwire_generic_allocation
remove_module snd_sof_intel_hda_sdw_bpt

#-------------------------------------------
# platform drivers - take2
#-------------------------------------------
# Attempt 2/2, see above.
remove_module snd_sof_intel_hda_common

remove_module snd_sof_intel_hda
remove_module snd_sof_intel_ipc
remove_module snd_sof_xtensa_dsp

#-------------------------------------------
# Helpers
#-------------------------------------------
remove_module snd_sof_acpi
remove_module snd_sof_pci
remove_module snd_sof_intel_atom
remove_module imx_common

#-------------------------------------------
# Machine drivers
#-------------------------------------------
remove_module snd_soc_sof_rt5682
remove_module snd_soc_sof_da7219_max98373
remove_module snd_soc_sof_da7219
remove_module snd_soc_sst_bdw_rt5677_mach
remove_module snd_soc_bdw_rt286
remove_module snd_soc_sst_broadwell
remove_module snd_soc_sst_bxt_da7219_max98357a
remove_module snd_soc_sst_sof_pcm512x
remove_module snd_soc_sst_bxt_rt298
remove_module snd_soc_sst_sof_wm8804
remove_module snd_soc_sst_byt_cht_da7213
remove_module snd_soc_sst_byt_cht_es8316
remove_module snd_soc_sst_bytcr_rt5640
remove_module snd_soc_sst_bytcr_rt5651
remove_module snd_soc_sst_cht_bsw_max98090_ti
remove_module snd_soc_sst_cht_bsw_nau8824
remove_module snd_soc_sst_cht_bsw_rt5645
remove_module snd_soc_sst_cht_bsw_rt5672
remove_module snd_soc_sst_glk_rt5682_max98357a
remove_module snd_soc_cml_rt1011_rt5682
remove_module snd_soc_skl_hda_dsp
remove_module snd_soc_sdw_rt700
remove_module snd_soc_sdw_rt711_rt1308_rt715
remove_module snd_soc_sof_sdw
remove_module snd_soc_sdw_utils
remove_module snd_soc_sof_es8336
remove_module snd_soc_ehl_rt5660
remove_module snd_soc_intel_sof_board_helpers
remove_module snd_soc_acpi_intel_match
remove_module snd_soc_intel_hda_dsp_common
remove_module snd_soc_intel_sof_cirrus_common
remove_module snd_soc_intel_sof_maxim_common
remove_module snd_soc_intel_sof_nuvoton_common
remove_module snd_soc_intel_sof_realtek_common

#-------------------------------------------
# SOF client drivers
#-------------------------------------------
remove_module snd_sof_probes
remove_module snd_sof_ipc_test
remove_module snd_sof_ipc_flood_test
remove_module snd_sof_ipc_msg_injector
remove_module snd_sof_ipc_kernel_injector
remove_module snd_sof_dma_trace

#-------------------------------------------
# SOF OF driver
#-------------------------------------------
remove_module snd_sof_of

# snd_sof_nocodec dependencies re-ordered
# in https://github.com/thesofproject/linux/pull/2800
# TODO: remove || true and the duplicate below
# when we stop testing old branches.
remove_module snd_sof_nocodec || true

remove_module snd_sof
remove_module snd_sof_nocodec
remove_module snd_sof_utils

#-------------------------------------------
# Codec drivers
#-------------------------------------------
remove_module snd_soc_da7213
remove_module snd_soc_da7219
remove_module snd_soc_pcm512x_i2c
remove_module snd_soc_pcm512x

remove_module snd_soc_cs35l56_sdw
remove_module snd_soc_cs35l56
#snd_soc_wm_adsp is used by snd_soc_cs35l56
remove_module snd_soc_wm_adsp
remove_module snd_soc_cs42l42_sdw
remove_module snd_soc_cs42l42

# inversion is intentional for cs42l43
remove_module snd_soc_cs42l43
remove_module snd_soc_cs42l43_sdw
remove_module cs42l43_sdw

remove_module snd_soc_rt274
remove_module snd_soc_rt286
remove_module snd_soc_rt298
remove_module snd_soc_rt700
remove_module snd_soc_rt711
remove_module snd_soc_rt711_sdca
remove_module snd_soc_rt712_sdca
remove_module snd_soc_rt712_sdca_dmic
remove_module snd_soc_rt715
remove_module snd_soc_rt715_sdca
remove_module snd_soc_rt722_sdca
remove_module snd_soc_rt1308
remove_module snd_soc_rt1308_sdw
remove_module snd_soc_rt1316_sdw
remove_module snd_soc_rt1318_sdw
remove_module snd_soc_rt1320_sdw
remove_module snd_soc_rt1011
remove_module snd_soc_rt1017-sdca
remove_module snd_soc_rt5640
remove_module snd_soc_rt5645
remove_module snd_soc_rt5651
remove_module snd_soc_rt5660
remove_module snd_soc_rt5670
remove_module snd_soc_rt5677
remove_module snd_soc_rt5677_spi
remove_module snd_soc_rt5682_sdw
remove_module snd_soc_rt5682_i2c
remove_module snd_soc_rt5682
remove_module snd_soc_rt5682s
remove_module snd_soc_rl6231
remove_module snd_soc_rl6347a
remove_module snd_soc_sdw_mockup

remove_module snd_soc_wm8804_i2c
remove_module snd_soc_wm8804

remove_module snd_soc_es8316
remove_module snd_soc_es8326

remove_module snd_soc_max98090
remove_module snd_soc_ts3a227e
remove_module snd_soc_max98357a
remove_module snd_soc_max98363
remove_module snd_soc_max98373_sdw
remove_module snd_soc_max98373_i2c
remove_module snd_soc_max98373
remove_module snd_soc_max98390

remove_module snd_soc_hdac_hda
remove_module snd_soc_hdac_hdmi
remove_module snd_hda_codec_intelhdmi
remove_module snd_hda_codec_hdmi
remove_module snd_soc_dmic

remove_module snd_hda_codec_realtek
remove_module snd_hda_codec_generic

remove_module snd_soc_wm8960

#-------------------------------------------
# Remaining core SOF parts
#-------------------------------------------
remove_module snd_soc_acpi

remove_module snd_intel_dspcfg

remove_module regmap_sdw
remove_module regmap_sdw_mbq
remove_module soundwire_bus
remove_module snd_intel_sdw_acpi

remove_module snd_sof_intel_hda_mlink
remove_module snd_hda_ext_core

#-------------------------------------------
# Remaining core ALSA/ASoC parts
#-------------------------------------------
remove_module snd_soc_acpi_intel_sdca_quirks
remove_module snd_soc_sdca
remove_module snd_soc_core
remove_module snd_hda_codec
remove_module snd_hda_core
remove_module snd_hwdep
remove_module snd_compress
remove_module snd_pcm_dmaengine
remove_module snd_pcm
remove_module snd_ctl_led
remove_module snd_seq_midi
remove_module snd_seq_midi_event
remove_module snd_rawmidi
remove_module snd_seq_dummy
remove_module snd_seq
remove_module snd_seq_device
remove_module snd_hrtimer
remove_module snd_timer
remove_module snd
remove_module soundcore
