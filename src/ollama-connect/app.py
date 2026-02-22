import os
import requests
from fastapi import FastAPI, Request, HTTPException, status
from pydantic import BaseModel
from fastapi import UploadFile, File, Form
import tempfile
import uuid
import shutil
import mimetypes
from typing import Optional

app = FastAPI()

SESSION = requests.Session()

# Allow uploads up to 2 GiB by default. This checks Content-Length and streams to disk.
MAX_UPLOAD_BYTES = 2 * 1024 * 1024 * 1024  # 2 GiB


def _required_env(name: str) -> str:
    val = os.environ.get(name)
    if val is None:
        raise RuntimeError(f"Missing required environment variable: {name}. Please set it in docker-compose.yml")
    return val


def _required_env_int(name: str) -> int:
    s = _required_env(name)
    try:
        return int(s)
    except ValueError:
        raise RuntimeError(f"Environment variable {name} must be an integer, got: {s}")


# Read required configuration from environment (set via Docker Compose)
OLLAMA_URL = _required_env("OLLAMA_URL")
OLLAMA_MODEL = _required_env("OLLAMA_MODEL")
DEFAULT_MAX_TOKENS = _required_env_int("OLLAMA_MAX_TOKENS")
DEFAULT_TIMEOUT = _required_env_int("OLLAMA_TIMEOUT")

class ChatRequest(BaseModel):
    message: str
    image: Optional[str] = None  # Base64-encoded image with data URI prefix


@app.post("/chat")
def chat(req: ChatRequest):
    # Use vision model if image is provided
    if req.image:
        return _generate_vision_response(req.message, req.image)
    else:
        return _generate_response(req.message)


def _generate_response(prompt: str):
    """Generate response using Ollama's native API"""
    resp = SESSION.post(
        f"{OLLAMA_URL}/api/chat",
        json={
            "model": OLLAMA_MODEL,
            "messages": [
                {"role": "user", "content": prompt}
            ],
            "stream": False,
            "options": {
                "num_predict": DEFAULT_MAX_TOKENS
            }
        },
        timeout=DEFAULT_TIMEOUT,
    )

    if resp.status_code != 200:
        try:
            err_payload = resp.json()
        except Exception:
            err_payload = {"error": resp.text}
        return {"response": f"Backend error: {err_payload}"}

    try:
        data = resp.json()
    except Exception:
        return {"response": resp.text}

    text = None
    if isinstance(data, dict):
        # Ollama native API returns message in data["message"]["content"]
        message = data.get("message")
        if isinstance(message, dict):
            text = message.get("content")

    if not text:
        # fallback to stringifying the response
        text = str(data)

    return {"response": text}


def _generate_vision_response(prompt: str, image_data: str):
    """Generate response using Ollama's vision model (llava) with image."""
    # Check if vision model is available
    try:
        models_resp = SESSION.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        models_data = models_resp.json() if models_resp.status_code == 200 else {}
        available_models = [m.get("name", "").split(":")[0] for m in models_data.get("models", [])]
        
        if "llava" not in available_models:
            return {
                "response": "Vision feature is not available. The llava model requires additional memory (4.7GB) "
                           "and may not be loaded on CPU-only systems to avoid memory constraints. "
                           "You can still use text-based recommendations! "
                           "If you want to enable vision, you can try: docker compose exec ollama ollama pull llava"
            }
    except Exception as e:
        print(f"Error checking available models: {e}")
    
    # Extract base64 data from data URI if present
    # Format: "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
    if image_data.startswith("data:"):
        # Split on comma to get the base64 part
        parts = image_data.split(",", 1)
        if len(parts) == 2:
            base64_image = parts[1]
        else:
            base64_image = image_data
    else:
        base64_image = image_data
    
    resp = SESSION.post(
        f"{OLLAMA_URL}/api/chat",
        json={
            "model": "llava",  # Use vision model
            "messages": [
                {
                    "role": "user",
                    "content": prompt,
                    "images": [base64_image]  # Ollama expects base64 without data URI prefix
                }
            ],
            "stream": False,
            "options": {
                "num_predict": DEFAULT_MAX_TOKENS
            }
        },
        timeout=DEFAULT_TIMEOUT,
    )

    if resp.status_code != 200:
        try:
            err_payload = resp.json()
            error_msg = str(err_payload.get("error", err_payload))
            # Check for memory/resource errors
            if "resource" in error_msg.lower() or "memory" in error_msg.lower() or "stopped" in error_msg.lower():
                return {
                    "response": "Vision model encountered a memory error. This is common on CPU-only systems. "
                               "The text-based recommendation system is available. "
                               "Try asking: 'What blue dresses do you have?' instead of uploading an image."
                }
        except Exception:
            err_payload = {"error": resp.text}
        return {"response": f"Vision error: {err_payload}"}

    try:
        data = resp.json()
    except Exception:
        return {"response": resp.text}

    text = None
    if isinstance(data, dict):
        message = data.get("message")
        if isinstance(message, dict):
            text = message.get("content")

    if not text:
        text = str(data)

    return {"response": text}


@app.post("/predict")
def predict(request: Request, prompt: str = Form(...), file: UploadFile | None = File(None)):
    # If a file is attached, save it and try to extract text for the prompt
    # Strictly check Content-Length header to avoid reading very large bodies into memory
    content_length = 0
    content_length_header = request.headers.get("Content-Length")
    if content_length_header:
        try:
            content_length = int(content_length_header)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid Content-Length")
    if content_length > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Payload too large (max {MAX_UPLOAD_BYTES} bytes)"
        )

    # Validate file type if present
    if file is not None and file.filename:
        filename = file.filename.lower()
        # Accept only text-based formats for simplicity
        allowed_extensions = (".txt", ".md", ".json", ".csv", ".log")
        if not filename.endswith(allowed_extensions):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported file type. Only text files allowed: {allowed_extensions}"
            )

        # Save to temporary file
        temp_dir = tempfile.mkdtemp()
        try:
            file_path = os.path.join(temp_dir, file.filename)
            with open(file_path, "wb") as f:
                shutil.copyfileobj(file.file, f)

            # Read content
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                file_content = f.read(10000)  # Limit to first 10k chars

            # Append file content to the prompt
            full_prompt = f"{prompt}\n\nFile content:\n{file_content}"
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)
    else:
        full_prompt = prompt

    return _generate_response(full_prompt)


@app.get("/health")
def health():
    """Health check endpoint"""
    return {"status": "healthy", "model": OLLAMA_MODEL, "ollama_url": OLLAMA_URL}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
