#pragma once

/**
 * UEFI Protocol - Graphics Output Protocol
 *
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <c-efi-base.h>
#include <c-efi-system.h>

#define C_EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID C_EFI_GUID(0x0964e5b22, 0x6459, 0x11d2, 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b)
#define C_EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_REVISION 0x00010000

#define C_EFI_FILE_PROTOCOL_REVISION 0x00010000
#define C_EFI_FILE_PROTOCOL_REVISION2 0x00020000
#define C_EFI_FILE_PROTOCOL_LATEST_REVISION C_EFI_FILE_PROTOCOL_REVISION2

//*******************************************************
// Open Modes
//*******************************************************
#define C_EFI_FILE_MODE_READ   0x0000000000000001
#define C_EFI_FILE_MODE_WRITE  0x0000000000000002
#define C_EFI_FILE_MODE_CREATE 0x8000000000000000

//*******************************************************
// File Attributes
//*******************************************************
#define C_EFI_FILE_READ_ONLY   0x0000000000000001
#define C_EFI_FILE_HIDDEN      0x0000000000000002
#define C_EFI_FILE_SYSTEM      0x0000000000000004
#define C_EFI_FILE_RESERVED    0x0000000000000008
#define C_EFI_FILE_DIRECTORY   0x0000000000000010
#define C_EFI_FILE_ARCHIVE     0x0000000000000020
#define C_EFI_FILE_VALID_ATTR  0x0000000000000037

#define C_EFI_FILE_INFO_GUID C_EFI_GUID(0x09576e92, 0x6d3f, 0x11d2, 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b)

//*******************************************************
// File Attribute Bits
//*******************************************************
#define C_EFI_FILE_READ_ONLY  0x0000000000000001
#define C_EFI_FILE_HIDDEN     0x0000000000000002
#define C_EFI_FILE_SYSTEM     0x0000000000000004
#define C_EFI_FILE_RESERVED   0x0000000000000008
#define C_EFI_FILE_DIRECTORY  0x0000000000000010
#define C_EFI_FILE_ARCHIVE    0x0000000000000020
#define C_EFI_FILE_VALID_ATTR 0x0000000000000037

#define C_EFI_FILE_SYSTEM_INFO_GUID C_EFI_GUID(0x09576e93, 0x6d3f, 0x11d2, 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b)
#define C_EFI_FILE_SYSTEM_VOLUME_LABEL_GUID C_EFI_GUID(0xdb47d7d3, 0xfe81, 0x11d3,  0x9a, 0x35 0x00, 0x90, 0x27, 0x3f, 0xC1, 0x4d)

typedef struct CEfiFileInfo {
	CEfiU64 size;
	CEfiU64 file_size;
	CEfiU64 physical_size;
	CEfiTime create_time;
	CEfiTime last_access_time;
	CEfiTime modification_time;
	CEfiU64 attribute;
	CEfiChar16 file_name[];
} CEfiFileInfo;

typedef struct CEfiFileSystemInfo {
	CEfiU64 size;
	CEfiBool read_only;
	CEfiU64 volume_size;
	CEfiU64 free_space;
	CEfiU32 block_size;
	CEfiChar16 volume_name[];
} CEfiFileSystemInfo;

typedef struct CEfiFileSystemVolumeLabel {
	CEfiChar16 volume_label[];
} CEfiFileSystemVolumeLabel;

typedef struct CEfiFileIoToken {
	CEfiEvent event;
	CEfiStatus status;
	CEfiUSize buffer_size;
	void* buffer;
} CEfiFileIoToken;

typedef struct CEfiFile {
	CEfiU64 revision;
	CEfiStatus (CEFICALL *open) (
		struct CEfiFile* this_,
		struct CEfiFile** new_handle,
		CEfiChar16* filename,
		CEfiU64 open_mode,
		CEfiU64 attributes
	);
	CEfiStatus (CEFICALL *close) (
		struct CEfiFile* this_
	);
	CEfiStatus (CEFICALL *delete) (
		struct CEfiFile* this_
	);
	CEfiStatus (CEFICALL *read) (
		struct CEfiFile* this_,
		CEfiUSize* buffer_size,
		void* buffer
	);
	CEfiStatus (CEFICALL *write) (
		struct CEfiFile* this_,
		CEfiUSize* buffer_size,
		void* buffer
	);
	CEfiStatus (CEFICALL *get_position) (
		struct CEfiFile* this_,
		CEfiU64* position
	);
	CEfiStatus (CEFICALL *set_position) (
		struct CEfiFile* this_,
		CEfiU64 position
	);
	CEfiStatus (CEFICALL *get_info) (
		struct CEfiFile* this_,
		CEfiGuid* info_type,
		CEfiUSize* buffer_size,
		void* buffer
	);
	CEfiStatus (CEFICALL *set_info) (
		struct CEfiFile* this_,
		CEfiGuid* info_type,
		CEfiUSize buffer_size,
		void* buffer
	);
	CEfiStatus (CEFICALL *flush) (
		struct CEfiFile* this_
	);
	CEfiStatus (CEFICALL *openex) (
		struct CEfiFile* this_,
		struct CEfiFile** new_handle,
		CEfiChar16* filename,
		CEfiU64 open_mode,
		CEfiU64 attributes,
		struct CEfiFileIoToken* token
	);
	CEfiStatus (CEFICALL *readex) (
		struct CEfiFile* this_,
		struct CEfiFileIoToken* token
	);
	CEfiStatus (CEFICALL *writeex) (
		struct CEfiFile* this_,
		struct CEfiFileIoToken* token
	);
	CEfiStatus (CEFICALL *flushex) (
		struct CEfiFile* this_,
		struct CEfiFileIoToken* token
	);
} CEfiFile;

typedef struct CEfiSimpleFileSystemProtocol {
	CEfiU64 revision;
	CEfiStatus (CEFICALL *open_volume) (
		struct CEfiSimpleFileSystemProtocol* this_,
		struct CEfiFile** root
	);
} CEfiSimpleFileSystemProtocol;

#ifdef __cplusplus
}
#endif
