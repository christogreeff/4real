# 4ReAL / Turbo Pascal + ASM Demo

A small DOS demo project from school days, originally written on 29 May 1998 to learn x86 assembly while already being comfortable with Turbo Pascal.

This repo contains [code/4rl2026.pas](code/4rl2026.pas), a bug-fixed (2026) copy of the original demo source.

I wrote this as my second demo ever. It is rough, direct, and very much in the style of late-90s Mode 13h experiments.

## Copyright and License

Copyright (c) 1998-2026 4ReAL.

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

AGPL requires preserving copyright/license notices and making source code available for distributed/modified versions (including software provided over a network).

Full terms: [LICENSE](LICENSE)

Author request (not an additional legal term):

- Please credit Christo Greeff in substantial reuse.
- Please clearly note what you changed.
- Please inform me of public usage or major changes by opening an issue in this repository.

## Videos

Demo first:

- Full video link (about 10 MB): [video/demo.10mb.mp4](video/demo.10mb.mp4)

[![Demo preview (35s-44s, click for full video)](video/demo.preview.webp)](video/demo.10mb.mp4)

[![Compile full-length WebP](video/compile.full.webp)](video/compile.mp4)

## What The Demo Does (from source)

Based on [code/4rl2026.pas](code/4rl2026.pas), the program runs several old-school software-rendered effects in VGA 320x200x256:

- Enters Mode 13h and writes directly to video memory ($A000).
- Uses custom assembler routines for line drawing, pixel access, clears, and page flipping.
- Uses vertical retrace sync and palette programming for smooth transitions and fades.
- Loads a custom binary font from 4real.fnt and renders zoomed text using an 8x8 bitmap per character.
- Shows a flashing title sequence.
- Generates a plasma effect.
- Renders a starfield plus a rotating/projected 3D point set loaded from OBJ.3D.
- Loads and displays an indexed image from GOLF.4RI (VW Golf), then applies sine-based distortion and motion effects.
- Runs a classic text-over-fire style effect.

## Asset Notes

### Custom Font

I wrote a FONTMAKE.PAS tool to build my own fonts using mouse input and Turbo Pascal BGI graphics.

That tool is not included in this repo right now, but the generated font is loaded by the demo as 4real.fnt.

Inferred from [code/4rl2026.pas](code/4rl2026.pas): the font file is a typed-record dump with glyph bits stored for ASCII 43..90, 64 bytes per glyph (8x8).

```pascal
Type
 Letters = Record
  No : Array [43..90,1..64] Of Byte
 End;

Procedure LoadFont(S : String; Var L : LetPtr);
Var
 F : File Of Letters;
Begin
 Assign(F,S);
 Reset(F);
 Read(F,L^);
 Close(F);
End;
```

Technical note: there is no per-file header/version in this loader path; structure compatibility depends on the exact Pascal record layout.

### GOLF.4RI

I do not currently remember the original conversion pipeline used in 1998.

The source image was a VW Golf model, likely a [Volkswagen Golf Mk3](https://en.wikipedia.org/wiki/Volkswagen_Golf_Mk3).

From [code/4rl2026.pas](code/4rl2026.pas), the file appears to be read as a raw typed record containing:

- Indexed pixel data: 260x160 bytes
- Palette: 256 entries x RGB (3 bytes)

Technical note: this maps to a fixed-size packed block of 42,368 bytes in Turbo Pascal record order (pixel indices first, then palette), with no explicit headers shown in the loader.

```pascal
Type
 Img = Record
  Pic : Array[1..260,1..160] Of Byte;
  Pl  : Array[0..255,0..2] Of Byte;
 End;

Assign(PicF,'Golf.4ri');
Reset(PicF);
Read(PicF,Pic^);
Close(PicF);
```

Technical note: rendering uses palette indices directly and then applies sine-based coordinate warping over the loaded pixel buffer.

### OBJ.3D

I do not currently remember the exact export/conversion steps either.

I might have used 3ds Max 2.5 at the time (retro reference: [3D Studio MAX 2.5 video](https://www.youtube.com/watch?v=y8azQEceSJo)).

From [code/4rl2026.pas](code/4rl2026.pas), OBJ.3D appears to be read as a raw typed record of 530 points x 3 coordinates (Real), used as a point cloud for rotation/projection.

Technical note: the loader performs a single typed-record read into memory, then rotates/projects each point directly; there is no face/index list in this effect path, only vertex positions.

```pascal
Type
 P = Array[1..530,1..3] Of Real;

Assign(PF,'OBJ.3d');
Reset(PF);
Read(PF,Pts^);
Close(PF);

For I := 1 to 530 do
 RotateProjection(Pts^[I,1],Pts^[I,2],Pts^[I,3],8,8,8,Xp,Yp,Xc,Yc,Zo);
```

Technical note: this is a direct binary ingest path, so changing Pascal Real size/compiler mode can break cross-tool compatibility.

## Source Credits

Original demo and tooling by 4ReAL (1998), with this repository preserving the work and a 2026 bug-fixed source copy.
