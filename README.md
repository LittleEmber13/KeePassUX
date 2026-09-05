# KeepassUX

A mobile application built with Flutter for managing passwords using the KDBX format (compatible with KeePass), with a strong focus on delivering a clean, elegant, and visually appealing user interface. The goal of the project is to offer a secure and intuitiv way to store and access passwords while prioritizing a polished UX.

## Features

- Open and view KDBX databases
- Create new KDBX databases
- Add, edit, copy, move and delete entries
- Add, editt, copy, move and delete groups
- Recycle bin with soft delete, permanent delete, and restore
- Change master password
- Search entries and groups
- Password generator
- Biometric authentication to unlock the database
- Screenshot prevention
- Dark/light theme
- Internationalization
- Auto fill

## Technologies Used

- **Flutter** — UI framework
- **kdbx.dart** — KDBX file reading and writing (https://github.com/authpass/kdbx.dart)
- **flutter_bloc** — State management
- **local_auth** — Biometric authentication
- **flutter_secure_storage** — Encrypted credential storage
- **easy_localization** — Internationalization
- **zxcvbnm** — Password strength estimation
- **file_picker / uri_content / content_resolver** — File system access via SAF

## Target Platforms

- Android

## Planned Features

- **IOS Support**
