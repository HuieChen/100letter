"""Verify/import unchanged selected embedded JPEGs from the explicitly supplied PDF.

No raster edits, white-background removal, AI calls or implicit asset registration.
The runtime compositor supplies white-matte alpha; original PDF is never changed.
"""
import argparse, hashlib, json
from pathlib import Path
import fitz
ROOT=Path(__file__).resolve().parents[1]
SOURCE_SHA='ff54771c8c7d98ee2d9cfeeac496eb203a324ebc96a3b9a5dcba9853f19c191f'
def main():
    p=argparse.ArgumentParser();p.add_argument('pdf',type=Path);p.add_argument('--verify-only',action='store_true');args=p.parse_args()
    if hashlib.sha256(args.pdf.read_bytes()).hexdigest()!=SOURCE_SHA:raise ValueError('The supplied source PDF fingerprint differs; preserve it and review a new source explicitly.')
    out=ROOT/'assets/faefever_v2/ui/settings_pdf_20261017'
    record=json.loads((out/'provenance.json').read_text(encoding='utf-8'))
    doc=fitz.open(args.pdf)
    if len(doc)!=39:raise ValueError('Expected 39 authored layer pages.')
    for item in record['items']:
        embedded=doc[item['page']-1].get_images(full=True)
        if len(embedded)!=1:raise ValueError('Expected one unchanged embedded JPEG for '+item['role'])
        raw=doc.extract_image(embedded[0][0])
        if raw['ext']!='jpeg' or (raw['width'],raw['height'])!=(1920,1080):raise ValueError('Unexpected source image encoding.')
        if hashlib.sha256(raw['image']).hexdigest()!=item['sha256']:raise ValueError('Original embedded bytes differ: '+item['role'])
        target=ROOT/item['path']
        if args.verify_only:
            if target.read_bytes()!=raw['image']:raise ValueError('Runtime source image differs: '+item['role'])
        else:
            if target.exists() and target.read_bytes()!=raw['image']:raise ValueError('Do not overwrite different authored bytes: '+str(target))
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw['image'])
    doc.close();print('Verified 11 exact embedded JPEG layers from 39-page original; white/blank export limitations remain documented.')
if __name__=='__main__':main()
