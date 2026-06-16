#!/bin/bash
# Select region, capture, upload, and copy URL to clipboard

IMG_PATH="/tmp/screenshot_$(date +%s).png"

# 1. Take a screenshot of a selected region
maim -s "$IMG_PATH"

if [ -f "$IMG_PATH" ]; then
    notify-send -t 2000 "Uploading Screenshot..." "Please wait."

    # 2. Upload to 0x0.st (a reliable anonymous file host)
    URL=$(curl -s -F "file=@${IMG_PATH}" https://0x0.st)

    if [[ $URL == http* ]]; then
        # 3. Copy to clipboard
        echo -n "$URL" | xclip -selection clipboard
        
        # 4. Notify success
        notify-send -t 4000 "Screenshot Uploaded" "URL copied to clipboard!\n$URL"
    else
        notify-send -u critical "Upload Failed" "Could not upload the screenshot."
    fi

    # Clean up
    rm "$IMG_PATH"
else
    # User likely pressed Esc to cancel the selection
    exit 0
fi
