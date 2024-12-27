import discord
import re
import requests
from io import BytesIO
from os import environ

scryfall_headers = {'User-Agent': 'mtg-cardfetcher-discord-selfbot'}

class MyClient(discord.Client):
    async def on_ready(self):
        print('Logged on as', self.user)

    async def on_message(self, message: discord.Message):
        if message.author != self.user:
            return

        results = re.findall('\\[\\[([^\\[\\]]+)\\]\\]', message.content)
        if len(results) == 0:
            return
        card = results[0]
        r = requests.get(f'https://api.scryfall.com/cards/named', params={'fuzzy': card}, headers=scryfall_headers)
        if r.status_code != 200:
            return
        if 'card_faces' in r.json():
            files = message.attachments.copy()
            for face in r.json()['card_faces']:
                r1 = requests.get(face['image_uris']['border_crop'], headers=scryfall_headers)
                if r1.status_code != 200:
                    return
                files.append(discord.File(BytesIO(r1.content), filename='image.png'))
            await message.edit(re.sub('(\\[\\[[^\\[\\]]+\\]\\])', f'[{card}](<{r.json()['scryfall_uri']}>)', message.content), attachments=files)
        else:
            r1 = requests.get(r.json()['image_uris']['border_crop'], headers=scryfall_headers)
            if r1.status_code != 200:
                return
            files = message.attachments.copy()
            files.append(discord.File(BytesIO(r1.content), filename='image.png'))
            await message.edit(re.sub('(\\[\\[[^\\[\\]]+\\]\\])', f'[{card}](<{r.json()['scryfall_uri']}>)', message.content), attachments=files)
        
def main():
    client = MyClient()
    client.run(environ['TOKEN'])