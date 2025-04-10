# System Architecture Documentation

The purpose of this repository is to ensure a shared understanding of the system architecture behind [**data.norge.no**](https://data.norge.no/en) — a national data catalog designed to support the sharing and discovery of public sector data in Norway — as well as adjacent or supporting systems.

And secondly to make collaboration easier, enable version control, and ensure the architecture documentation remains up-to-date.

We use the C4 model to provide a structured approach for describing the system at various levels of abstraction with a consistent set of notations.

👉 **Visit the [wiki](https://github.com/Informasjonsforvaltning/architecture-documentation/wiki/Architecture-documentation) for a more in-depth description of the system architecture.**

## Key Levels of Documentation

We focus on two key levels of abstraction to provide a clear and concise overview of the system:

### System Level
* **Purpose**: Show how the system operates as a whole.
* **Content**: Identify users and external actors interacting with the system. Illustrate how the system integrates and communicates with other systems.

### Container Level
* **Purpose**: Describe the deployable parts of the system. 
* **Content**: Detail the applications, databases, and services that make up the system. Explain how these components interact with each other.

## How to Contribute 
1. Download the draw.io desktop app (or plugin for VS Code or IntelliJ)
2. Clone the repository 
3. Edit or add diagrams as needed, following the C4 model (shapes in draw.io)
4. Open a pull request with a detailed description of the addition or changes
5. The pull request will start a workflow that converts all .drawio files in the C4-folder to .svg in the generated-folder
6. Create and describe a new release if the pull request adds or removes components from one or more diagrams
