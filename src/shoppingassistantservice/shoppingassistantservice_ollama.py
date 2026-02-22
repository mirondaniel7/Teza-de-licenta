#!/usr/bin/python
#
# Shopping Assistant Service using Ollama
# Integrates with Online Boutique to provide AI-powered product recommendations

import os
import requests
import json
from urllib.parse import unquote
from flask import Flask, request, jsonify
import grpc
import demo_pb2
import demo_pb2_grpc

# Configuration from environment
AI_INFERENCE_URL = os.environ.get("AI_INFERENCE_URL", "http://ai-inference:8000")
PRODUCT_CATALOG_SERVICE_ADDR = os.environ.get("PRODUCT_CATALOG_SERVICE_ADDR", "productcatalogservice:3550")

def get_all_products():
    """Fetch all products from the product catalog service via gRPC"""
    try:
        channel = grpc.insecure_channel(PRODUCT_CATALOG_SERVICE_ADDR)
        stub = demo_pb2_grpc.ProductCatalogServiceStub(channel)
        response = stub.ListProducts(demo_pb2.Empty())
        products = []
        for product in response.products:
            products.append({
                "id": product.id,
                "name": product.name,
                "description": product.description,
                "price": f"{product.price_usd.currency_code} {product.price_usd.units}.{product.price_usd.nanos:02d}",
                "categories": list(product.categories)
            })
        return products
    except Exception as e:
        print(f"Error fetching products: {e}")
        return []

def chat_with_ollama(message, image=None):
    """Send a message to the Ollama-based AI inference service"""
    try:
        payload = {"message": message}
        if image:
            payload["image"] = image
            
        response = requests.post(
            f"{AI_INFERENCE_URL}/chat",
            json=payload,
            timeout=90
        )
        if response.status_code == 200:
            data = response.json()
            return data.get("response", "No response from AI")
        else:
            return f"Error: AI service returned status {response.status_code}"
    except Exception as e:
        print(f"Error calling AI service: {e}")
        return f"Error communicating with AI: {str(e)}"

def create_app():
    app = Flask(__name__)

    @app.route("/", methods=['POST'])
    def assistant_chat():
        """Handle chat requests from the frontend"""
        try:
            print("Shopping Assistant request received")
            
            # Get the user's message and optional image
            user_message = request.json.get('message', '')
            user_message = unquote(user_message)
            user_image = request.json.get('image')  # Base64-encoded image
            
            if not user_message:
                return jsonify({"content": "Please provide a message"}), 400
            
            print(f"User message: {user_message}")
            if user_image:
                print("Image detected - using vision model")
            
            # Get all products from catalog
            products = get_all_products()
            print(f"Retrieved {len(products)} products from catalog")
            
            # Build a context with product information
            product_context = "Here are the available products in our store:\n\n"
            for i, product in enumerate(products[:20], 1):  # Limit to 20 products to avoid token limit
                product_context += f"{i}. {product['name']} (ID: {product['id']})\n"
                product_context += f"   Description: {product['description']}\n"
                product_context += f"   Price: {product['price']}\n"
                product_context += f"   Categories: {', '.join(product['categories'])}\n\n"
            
            # Create the full prompt for the AI
            if user_image:
                # Vision-enabled prompt
                full_prompt = f"""You are a helpful shopping assistant for Online Boutique, an e-commerce store.
The customer has shared an image. Please analyze the image and help them find products that match the style, colors, or items shown.

{product_context}

Customer's question: {user_message}

Based on the image and their question, provide helpful recommendations. Include product IDs in square brackets like [PRODUCT_ID] at the end of your response.
Be friendly, helpful, and concise. Focus on products that visually match what you see in the image."""
            else:
                # Text-only prompt
                full_prompt = f"""You are a helpful shopping assistant for Online Boutique, an e-commerce store.
Your role is to help customers find the perfect products based on their needs.

{product_context}

Customer's question: {user_message}

Please provide helpful recommendations. If you recommend specific products, include their product IDs in square brackets like [PRODUCT_ID] at the end of your response.
Be friendly, helpful, and concise. Focus on products that best match what the customer is looking for."""

            print("Sending request to AI service...")
            
            # Get response from Ollama via AI inference service
            ai_response = chat_with_ollama(full_prompt, user_image)
            
            print(f"AI Response: {ai_response[:200]}...")  # Log first 200 chars
            
            # Return the response in the format expected by the frontend
            return jsonify({"content": ai_response})
            
        except Exception as e:
            print(f"Error in assistant_chat: {e}")
            return jsonify({"content": f"Sorry, I encountered an error: {str(e)}"}), 500

    @app.route("/health", methods=['GET'])
    def health():
        """Health check endpoint"""
        return jsonify({"status": "healthy"}), 200

    return app

if __name__ == "__main__":
    # Create an instance of flask server when called directly
    app = create_app()
    app.run(host='0.0.0.0', port=80, debug=True)
