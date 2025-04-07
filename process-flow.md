# PDF Ingest Process Flow

```mermaid
flowchart TD
    User([User]) -->|Upload PDF| A[Azure Blob Storage\nInbox Container]
    A -->|Blob Created| B[Azure Queue Storage\nOCR Queue]
    B -->|Queue Message Triggers| C[Azure Function\nInbox Container]
    C -->|Extract Text| D{AI Vision Processing}
    D -->|Process PDF| E[PDF to Images]
    E -->|For Each Page| F[AI Vision OCR]
    F -->|Extract Text| G[Markdown Generation]
    G -->|Store Results| H[Azure Blob Storage\nOutbox Container]
    H -->|Blob Created| I[Azure Function\nOutbox Processor]
    I -->|Process Results| J[Final Markdown Document]
    
    subgraph "AI Models"
        D
        F
    end
    
    subgraph "Azure Storage"
        A
        B
        H
    end
    
    subgraph "Azure Functions"
        C
        I
    end
    
    classDef azure fill:#0072C6,color:white,stroke:#0072C6,stroke-width:2px;
    classDef ai fill:#19A275,color:white,stroke:#19A275,stroke-width:2px;
    classDef storage fill:#3B48CC,color:white,stroke:#3B48CC,stroke-width:2px;
    classDef function fill:#0078D7,color:white,stroke:#0078D7,stroke-width:2px;
    
    class A,B,H storage;
    class C,I function;
    class D,F ai;
    class User azure;
```

The diagram illustrates the PDF processing flow through the Azure-based architecture:

1. User uploads a PDF document to the Azure Blob Storage inbox container
2. A message is generated in the Azure Queue Storage
3. The queue message triggers the Inbox Container Azure Function
4. The function processes the PDF using AI vision models:
   - Converts PDF to images
   - Processes each image with the AI vision model for OCR
   - Converts extracted text to markdown format
5. The results are stored in the Azure Blob Storage outbox container
6. The new blob in the outbox container triggers the Outbox Processor Azure Function
7. The function finalizes the markdown document with the complete OCR results