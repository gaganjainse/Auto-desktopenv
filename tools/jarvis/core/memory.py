import importlib.metadata
_chroma_ver = importlib.metadata.version("chromadb")
assert tuple(int(x) for x in _chroma_ver.split(".")[:2]) >= (1, 5), \
    f"ChromaDB >=1.5.9 required, got {_chroma_ver}"
