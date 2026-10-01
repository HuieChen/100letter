"""Create the committed readable static instance. Requires fontTools."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

root = Path(__file__).resolve().parents[1] / 'assets' / 'fonts'
font = TTFont(root / 'NotoSansSC.ttf')
instance = instantiateVariableFont(font, {'wght': 450}, inplace=False)
instance.save(root / 'SolmereSans.ttf')
print('Created static wght=450 instance; retain OFL.txt with the font.')
