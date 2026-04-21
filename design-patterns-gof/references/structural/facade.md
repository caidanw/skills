# Facade

**Category:** Structural · **Modern relevance:** Very high (SDK clients, service layers)

## Intent

Provide a single, simplified entry point to a complex subsystem, hiding its internals from callers.

## Problem

A library or subsystem exposes 40 classes with intricate initialization order and
interdependencies. Clients shouldn't need to know any of that to convert a video or send an email.

## Structure

- **Facade** — the one-stop shop; orchestrates subsystem calls.
- **Subsystem classes** — unchanged, still usable directly if needed.
- **Client** — talks only to the Facade.
- **Additional Facades** — prevent one god-facade.

## Applicability

- Narrow, task-oriented API over a broad library.
- Layering a system; minimize inter-layer coupling.
- Public SDK over messy internals.

## Consequences

**Pros:** Massively simpler client code. Decouples client from subsystem evolution. Natural seam
for testing.

**Cons:** Can become a god object — every new feature tacked onto the same class until it's 3000
lines.

## When NOT to use

- The subsystem is already simple. Don't wrap one class in another class.
- Clients legitimately need the full power of the subsystem — a Facade will get in the way or grow
  to mirror it.
- You're tempted to make the Facade "flexible" with 20 parameters. That's the subsystem again.

## Modern relevance

Very high. jQuery was a Facade over the DOM. `fetch` is a Facade over XHR/networking. AWS SDK
high-level clients (`DocumentClient` over DynamoDB) are Facades. Most "service" classes in business
code are Facades. The `ffmpeg` CLI is a Facade over libav.

## Code sketch (Python)

```python
class VideoFile: ...
class CodecFactory: ...
class BitrateReader: ...
class AudioMixer: ...

class VideoConverter:                  # Facade
    def convert(self, filename: str, fmt: str) -> bytes:
        file = VideoFile(filename)
        codec = CodecFactory.extract(file)
        target_codec = CodecFactory.for_format(fmt)
        buffer = BitrateReader.read(filename, codec)
        result = BitrateReader.convert(buffer, target_codec)
        return AudioMixer().fix(result)

data = VideoConverter().convert("in.ogg", "mp4")
```

## Real-world uses

- jQuery over DOM APIs
- Python `requests` over `urllib3`
- AWS SDK high-level clients (DynamoDB `DocumentClient`, S3 `Upload`)
- Most ORMs (facade over query builder + connection pool + migrations)
- Stripe's high-level SDK

## Distinguishing from neighbors

- **vs. Adapter** — Adapter makes *one* incompatible object usable; Facade defines a *new* simpler
  interface over *many* objects.
- **vs. Mediator** — Mediator's colleagues only talk *through* it and know it. Facade's subsystem
  doesn't know the Facade exists — one-way simplification.
- **vs. Proxy** — Proxy matches the service's interface; Facade invents its own.

## Rule of thumb

Split Facades early by use case (`PaymentsFacade`, `RefundsFacade`), not by subsystem boundary. The
god-facade anti-pattern comes from treating "the Facade" as a singular entity instead of many
task-scoped ones.
