# App Store Materials

This folder is the single entry point for App Store submission materials.

## Layout

- `metadata/`: App Store Connect metadata managed by `asc metadata`.
- `screenshots/<version>/raw/`: Original screenshots captured from simulator or device.
- `screenshots/<version>/framed/`: Final framed screenshots ready for validation and upload.
- `screenshots/<version>/review/`: Screenshot review artifacts generated before upload.
- `review/<version>/`: Review notes, submission checklist, and version-specific release notes.
- `shared/`: Long-lived app information such as privacy notes, support copy, brand notes, and keyword research.

## Common Commands

```bash
asc metadata pull --dir ./AppStore/metadata
asc metadata validate --dir ./AppStore/metadata
asc screenshots validate --path ./AppStore/screenshots/1.0/framed --device-type IPHONE_65
```
