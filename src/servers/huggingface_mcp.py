import asyncio
from mcp import Server, types
from huggingface_hub import InferenceClient
import os

class HuggingFaceMCPServer:
    def __init__(self):
        self.server = Server("huggingface-mcp")
        self.client = InferenceClient(token=os.getenv("HF_TOKEN"))
        
        self.server.list_tools().callback(self.list_tools)
        self.server.call_tool().callback(self.call_tool)
    
    async def list_tools(self) -> list[types.Tool]:
        return [
            types.Tool(
                name="text_generation",
                description="Generate text using Hugging Face models",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "prompt": {"type": "string"},
                        "model": {"type": "string", "default": "mistralai/Mistral-7B-Instruct-v0.2"},
                        "max_tokens": {"type": "number", "default": 100}
                    },
                    "required": ["prompt"]
                }
            )
        ]
    
    async def call_tool(self, name: str, arguments: dict):
        if name == "text_generation":
            response = self.client.text_generation(
                arguments["prompt"],
                model=arguments.get("model", "mistralai/Mistral-7B-Instruct-v0.2"),
                max_new_tokens=arguments.get("max_tokens", 100)
            )
            return [types.TextContent(type="text", text=response)]

async def main():
    server = HuggingFaceMCPServer()
    await server.server.run()

if __name__ == "__main__":
    asyncio.run(main())