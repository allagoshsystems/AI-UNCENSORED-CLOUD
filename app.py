import os

import gradio as gr

try:
    from llama_cpp import Llama
except ImportError:  # pragma: no cover
    Llama = None

MODEL_PATH = os.environ.get("MODEL_PATH", "")
llm = None


def load_model():
    global llm
    if Llama is None:
        return None
    if not MODEL_PATH or not os.path.exists(MODEL_PATH):
        return None
    llm = Llama(model_path=MODEL_PATH, n_ctx=4096, verbose=False)
    return llm


model = load_model()


def respond(prompt: str, max_tokens: int = 256, temperature: float = 0.7):
    if Llama is None:
        return "llama-cpp-python is not installed. Re-run the workflow after dependencies install successfully."

    if model is None:
        return (
            "No GGUF model was found. Set MODEL_PATH to a valid .gguf file in the runner environment, "
            "or place the model in the repository before running the workflow."
        )

    output = model(
        prompt,
        max_tokens=max_tokens,
        temperature=temperature,
        stop=["</s>"],
        echo=False,
    )
    return output["choices"][0]["text"].strip()


with gr.Blocks(title="Gemma4 Jailbroken Local Model") as demo:
    gr.Markdown("# Local LLM Demo")
    gr.Markdown(
        "Set the `MODEL_PATH` environment variable to a valid GGUF model file before launching. "
        "If the model file is not present, the app starts in a no-model message mode."
    )
    with gr.Row():
        prompt = gr.Textbox(
            label="Prompt",
            value="Write a short hello message for an AI app.",
            lines=4,
            max_lines=10,
        )
    with gr.Row():
        max_tokens = gr.Slider(minimum=32, maximum=512, value=256, step=16, label="Max tokens")
        temperature = gr.Slider(minimum=0.0, maximum=1.5, value=0.7, step=0.1, label="Temperature")
    output = gr.Textbox(label="Response", lines=12)
    submit = gr.Button("Generate")
    submit.click(respond, inputs=[prompt, max_tokens, temperature], outputs=[output])


if __name__ == "__main__":
    demo.launch(server_name="0.0.0.0", server_port=7860, share=False)
