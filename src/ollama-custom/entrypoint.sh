#!/bin/bash

# Start Ollama server in background
/bin/ollama serve &

# Wait for server to be ready
echo "Waiting for Ollama server to start..."
sleep 5

# TEXT MODE: Check if model exists, if not pull it
# COMMENTED FOR VISION TESTING - uncomment to restore text mode
#if ! ollama list | grep -q "llama3.1"; then
#    echo "Model llama3.1 not found. Pulling..."
#    ollama pull llama3.1
#    echo "Model llama3.1 pulled successfully!"
#else
#    echo "Model llama3.1 already exists."
#fi

# VISION TESTING MODE: Load llava model for JPEG testing
# COMMENTED OUT - uncomment to test vision mode (requires more memory)
if ! ollama list | grep -q "llava"; then
    echo "Vision model llava not found. Pulling..."
    ollama pull llava
    echo "Model llava pulled successfully!"
else
    echo "Model llava already exists."
fi

echo "Vision Testing Mode: llava model loaded for JPEG/image analysis."
echo "To switch back to text mode: comment llava section and uncomment llama3.1 section above."
echo "Note: Running both models simultaneously may cause out-of-memory errors on CPU systems."

# Keep container running
wait
