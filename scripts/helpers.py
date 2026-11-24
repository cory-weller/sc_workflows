from pathlib import Path

class DotDict(dict):
    """
    A dictionary subclass that enables dot notation for accessing, 
    setting, and deleting keys recursively.
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Recursively convert any nested dict inputs into DotDicts
        for key, value in self.items():
            self[key] = self._convert(value)

    def __getattr__(self, key):
        try:
            return self[key]
        except KeyError:
            raise AttributeError(f"'DotDict' object has no attribute '{key}'")

    def __setattr__(self, key, value):
        self[key] = self._convert(value)

    def __delattr__(self, key):
        try:
            del self[key]
        except KeyError:
            raise AttributeError(f"'DotDict' object has no attribute '{key}'")

    def _convert(self, value):
        """Recursively process values to handle nested dictionaries and lists."""
        if isinstance(value, dict) and not isinstance(value, DotDict):
            return DotDict(value)
        elif isinstance(value, list):
            return [self._convert(item) for item in value]
        return value


def require_path(path, label, kind, create=False):
    """kind must be 'file' or 'dir'."""
    if kind not in ("file", "dir"):
        raise ValueError("kind must be 'file' or 'dir'")
    path = Path(path).resolve()
    if path.exists():
        # exists — verify it's the right type
        if kind == "file" and not path.is_file():
            raise FileNotFoundError(f"{label} {path} exists but is not a file")
        if kind == "dir" and not path.is_dir():
            raise NotADirectoryError(f"{label} {path} exists but is not a directory")
        return path.absolute()
    # doesn't exist
    if not create:
        raise FileNotFoundError(f"required {label} {kind} {path} does not exist")
    elif create:
        try:
            if kind == "file":
                path.parent.mkdir(parents=True, exist_ok=True)  # ensure parent dir
                path.touch()
            elif kind == 'dir':
                path.mkdir(parents=True, exist_ok=True)
            return path.absolute()
        except OSError as e:
            raise OSError(f"ERROR: could not create {label} {kind} {path}") from e



def get_md5(path:PosixPath):
    path = str(path.resolve().absolute())
    hash_md5 = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()
