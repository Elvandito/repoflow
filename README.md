# RepoFlow

**RepoFlow** is a lightweight, responsive, and powerful web-based GitHub repository management application. Built with HTML5, Tailwind CSS, and Vanilla JavaScript, this tool allows you to manage your entire GitHub ecosystem directly from your browser or via a mobile application without the need for a local Git installation.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![GitHub top language](https://img.shields.io/github/languages/top/username/repoflow)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

---

## Key Features

*   **Full Repository Access**: Create, view, and delete repositories directly within the application.
*   **File Explorer and Manager**: Intuitive folder navigation, file creation, built-in code editing, and file deletion.
*   **Streamlined Uploads**: Upload files from your local device directly to any directory in your repository.
*   **Batch Deletion**: Bulk selection functionality to remove multiple files in a single operation.
*   **Secure Authentication Persistence**: Persistent login using Personal Access Tokens (PAT) stored securely via `localStorage`.
*   **Advanced Settings**: Active token management, GitHub profile visualization, and direct links to GitHub Developer settings.
*   **Cross-Platform Responsiveness**: Optimized for seamless performance across Desktop, Tablet, and Mobile devices.
*   **Custom Interface Components**: Enhanced user experience utilizing modern, synchronized confirmation dialogs.

---

## Interface Preview

<img width="1920" height="1440" alt="ss" src="https://github.com/user-attachments/assets/3971c158-bb62-470d-a078-a800304f1ee5" />


---

## Technical Specifications

*   **Frontend Framework**: [Tailwind CSS](https://tailwindcss.com/) for styling and [Lucide Icons](https://lucide.dev/) for iconography.
*   **API Integration**: [GitHub REST API v3](https://docs.github.com/en/rest).
*   **Data Persistence**: Browser-based LocalStorage.
*   **Core Logic**: Vanilla JavaScript (ES6+).

---

## Installation and Setup

RepoFlow can be deployed as a web application or installed as an Android application.

### Android Installation
1.  **Download**: Navigate to the [Releases](https://github.com/Elvandito/repoflow/releases/latest) section of this repository.
2.  **Select Asset**: Download the latest `.apk` file.
3.  **Install**: Open the downloaded file on your Android device. 
    *   *Note: You may need to enable "Install from Unknown Sources" in your device settings.*
4.  **Permissions**: Grant the necessary storage permissions to allow file uploads to your repositories.

### Web Deployment
1.  **Clone the Repository**:
    ```bash
    git clone [https://github.com/Elvandito/repoflow.git
    ```
2.  **Execution**: Open `index.html` in any modern web browser. No local server is required.

---

## Authentication Setup

To use RepoFlow, you must provide a GitHub Personal Access Token (PAT).

1.  **Generate Token**: 
    *   Navigate to [GitHub Settings > Developer Settings](https://github.com/settings/tokens).
    *   Select **Generate new token (classic)**.
2.  **Scopes**: Ensure you grant the `repo` and `delete_repo` scopes to allow full management capabilities.
3.  **Login**: Copy the generated token and paste it into the RepoFlow Pro login screen. Your token is stored locally and never sent to third-party servers.

---

## Security and Privacy

*   **Token Security**: This application communicates exclusively with the official GitHub API. Your token is never transmitted to any external servers.
*   **Local Storage**: Authentication tokens are stored locally on your device. Always use the logout function when operating on shared or public devices.
*   **Transparency**: The source code is fully open for security audits and community review.

---

## Contributing

Community contributions are welcome. To contribute:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/ProposedFeature`).
3. Commit your modifications (`git commit -m 'Add ProposedFeature'`).
4. Push to the branch (`git push origin feature/ProposedFeature`).
5. Open a Pull Request.

---

## License

This project is licensed under the terms of the MIT License. Refer to the [LICENSE](LICENSE) file for further details.

---

**Developed for the global developer community.**
