# Online Boutique with Ollama AI Shopping Assistant

This is the Google Cloud Online Boutique demo integrated with an Ollama-powered AI shopping assistant.

## Architecture

The application now includes:

### Core Microservices (11 services)
- **frontend** - Web UI (http://localhost:8081)
- **productcatalogservice** - Product listings
- **cartservice** - Shopping cart
- **checkoutservice** - Order processing
- **paymentservice** - Payment handling
- **shippingservice** - Shipping calculations
- **emailservice** - Email notifications
- **currencyservice** - Currency conversion
- **recommendationservice** - Product recommendations
- **adservice** - Advertisements
- **loadgenerator** - Load testing

### AI Integration (4 services)
- **ollama** - LLM backend running Llama 3.1 (http://localhost:11434)
- **ai-inference** - FastAPI service for AI requests (http://localhost:8000)
- **chat-ui** - Standalone chat interface (http://localhost:8501)
- **shoppingassistantservice** - AI shopping assistant integrated into the store

### Data Store
- **redis-cart** - Redis for cart persistence

## How the AI Integration Works

1. **User asks a question** in the Online Boutique frontend about products
2. **Frontend** sends request to `shoppingassistantservice:80`
3. **Shopping Assistant Service**:
   - Fetches all products from `productcatalogservice` via gRPC
   - Creates a context with product information
   - Sends enriched prompt to `ai-inference:8000/chat`
4. **AI Inference Service** forwards to Ollama
5. **Ollama** generates response using Llama 3.1 model
6. Response flows back through the chain to the user

## Quick Start

### Prerequisites
- Docker Desktop with GPU support (optional but recommended)
- Your AI images already built: `ai-test:latest` and `ai-front:latest`

### First Time Setup

1. **Start the services:**
   ```powershell
   cd "c:\Users\User\Desktop\Daniel stuff\Teza-de-licenta"
   docker compose up --build
   ```

2. **Load the Ollama model** (first time only):
   ```powershell
   docker exec -it teza-de-licenta-ollama-1 ollama pull llama3.1
   ```

3. **Access the application:**
   - **Main Store**: http://localhost:8081
   - **Standalone Chat UI**: http://localhost:8501
   - **AI Inference API**: http://localhost:8000/docs
   - **Ollama API**: http://localhost:11434

### Testing the AI Assistant

1. Open http://localhost:8081
2. Look for the shopping assistant feature in the frontend
3. Ask questions like:
   - "I need something for my home office"
   - "What products do you have for outdoor activities?"
   - "Show me vintage items"

The AI will respond with product recommendations and include product IDs.

## Service Ports

| Service | Port | Description |
|---------|------|-------------|
| frontend | 8081 | Main web interface |
| recommendationservice | 8082 | Product recommendations |
| shoppingassistantservice | 8083 | AI shopping assistant |
| productcatalogservice | 3550 | Product catalog gRPC |
| checkoutservice | 5050 | Checkout gRPC |
| emailservice | 5000 | Email gRPC |
| redis-cart | 6379 | Redis cache |
| currencyservice | 7000 | Currency gRPC |
| cartservice | 7070 | Cart gRPC |
| ai-inference | 8000 | AI API (FastAPI) |
| chat-ui | 8501 | Streamlit chat |
| adservice | 9555 | Ads gRPC |
| ollama | 11434 | Ollama LLM API |
| paymentservice | 50051 | Payment gRPC |
| shippingservice | 50052 | Shipping gRPC |

## Troubleshooting

### Ollama model not loaded
```powershell
docker exec -it teza-de-licenta-ollama-1 ollama list
docker exec -it teza-de-licenta-ollama-1 ollama pull llama3.1
```

### Check service logs
```powershell
docker compose logs shoppingassistantservice
docker compose logs ai-inference
docker compose logs ollama
```

### Rebuild specific service
```powershell
docker compose up --build shoppingassistantservice
```

### Port conflicts
If port 8080 or others are in use, modify the port mappings in docker-compose.yml

## Customization

### Change AI Model
Edit docker-compose.yml:
```yaml
ai-inference:
  environment:
    - OLLAMA_MODEL=llama3.1  # Change to your preferred model
    - OLLAMA_MAX_TOKENS=8192
```

### Adjust Product Limit
Edit `src/shoppingassistantservice/shoppingassistantservice_ollama.py`:
```python
for i, product in enumerate(products[:20], 1):  # Change 20 to your limit
```

## Architecture Diagram

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       v
┌─────────────────┐
│    Frontend     │ :8081
└────────┬────────┘
         │
         ├──────────────────────────────┐
         │                              │
         v                              v
┌──────────────────────┐    ┌────────────────────────┐
│ Shopping Assistant   │    │   Other Services       │
│     Service          │    │ (cart, checkout, etc)  │
└──────┬───────────────┘    └────────────────────────┘
       │
       ├─────────────┐
       │             │
       v             v
┌─────────────┐  ┌──────────────────┐
│  Product    │  │  AI Inference    │ :8000
│  Catalog    │  │    (FastAPI)     │
└─────────────┘  └────────┬─────────┘
                          │
                          v
                  ┌──────────────┐
                  │    Ollama    │ :11434
                  │  (Llama 3.1) │
                  └──────────────┘
```

## Development

### Update Shopping Assistant Logic
1. Edit `src/shoppingassistantservice/shoppingassistantservice_ollama.py`
2. Rebuild: `docker compose up --build shoppingassistantservice`

### Update AI Inference Service
1. Update your `ai-integration` code
2. Rebuild your images
3. Restart: `docker compose restart ai-inference`

## License

Based on Google Cloud's microservices-demo, Apache License 2.0
AI integration with Ollama - Custom implementation
