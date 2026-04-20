gh codespace ssh -c scaling-yodel-5v5rqj5wg57h77vv -- "cat /workspaces/faster-whisper/xos_model_conversion_outputs/whisper-tiny-ct2.tar.gz" > whisper-tiny-ct2.tar.gz

downloading the file from github codespaces

then `hf upload nollied/whisper-ct2rs-models ./xos_model_conversion_outputs` for uploading to huggingface (the folder and subfolder items inside of it)