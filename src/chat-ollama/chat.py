import os
import streamlit as st
import requests
import json
import streamlit.components.v1 as components

st.title("Ollama Chat")

# Configure backend URL via environment (set in docker-compose)
API_URL = os.getenv("API_URL", "http://localhost:8000")

# Simple chat history kept in session state
if "history" not in st.session_state:
    st.session_state.history = []

with st.form("chat_form", clear_on_submit=True):
    user_input = st.text_input("You:")
    uploaded_file = st.file_uploader("Attach file (optional)")
    submitted = st.form_submit_button("Send")

if submitted and user_input:
    files = None
    data = {"prompt": user_input, "max_tokens": 64}
    if uploaded_file is not None:
        # Pass the uploaded file object directly to requests so it can stream
        files = {"file": (uploaded_file.name, uploaded_file, uploaded_file.type)}

    try:
        resp = requests.post(f"{API_URL}/predict", data=data, files=files)
        payload = resp.json()
    except Exception as e:
        payload = {"response": f"Request failed: {e}"}

    answer = payload.get("response") or payload.get("error") or str(payload)
    st.session_state.history.append({"user": user_input, "assistant": answer})

# Prefer rendering via the external HTML template if it exists
tpl_path = os.path.join(os.path.dirname(__file__), "static", "chat_ui.html")
if os.path.exists(tpl_path):
    try:
        tpl = open(tpl_path, "r", encoding="utf-8").read()
        history_json = json.dumps(st.session_state.history)
        html = tpl.replace("{{HISTORY_JSON}}", history_json)
        components.html(html, height=480, scrolling=True)
    except Exception as e:
        # fallback to simple markdown if template fails
        for turn in st.session_state.history:
            st.markdown(f"**You:** {turn['user']}")
            st.markdown(f"**AI:** {turn['assistant']}")
else:
    for turn in st.session_state.history:
        st.markdown(f"**You:** {turn['user']}")
        st.markdown(f"**AI:** {turn['assistant']}")