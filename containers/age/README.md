# Age Container Image

Container image for [age](https://github.com/FiloSottile/age), a simple, modern and secure encryption tool.

## Usage

```bash
docker pull ghcr.io/mirceanton/age:latest
```

### Encrypt a file

```bash
docker run --rm -v $(pwd):/data ghcr.io/mirceanton/age \
  -c "age --recipient <recipient> --output /data/secret.txt.age /data/secret.txt"
```

### Decrypt a file

```bash
docker run --rm -v $(pwd):/data ghcr.io/mirceanton/age \
  -c "age --decrypt --identity /data/key.txt --output /data/secret.txt /data/secret.txt.age"
```

### Generate a key pair

```bash
docker run --rm ghcr.io/mirceanton/age -c "age-keygen --output /data/key.txt"
```

## Included Tools

- `age` - encryption/decryption tool
- `age-keygen` - key generation tool
- `bash` - shell
- `git` - version control


