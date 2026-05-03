# RVC Voice Conversion - GitHub Actions

真正的RVC语音转换，将真人演唱的歌曲转换为哈利波特角色声音。

## 使用方法

1. Fork 这个仓库
2. 进入 Actions → "RVC Voice Conversion - Harry Potter"
3. 点击 "Run workflow"
4. 填写参数：
   - **audio_url**: 真人演唱歌曲的URL
   - **pitch**: 音调调整（邓布利多建议-9，斯内普建议-6）
   - **model_choice**: 选择角色
5. 等待完成，下载Artifacts中的音频

## 模型来源

- **邓布利多**: [Loren85/Albus-Dumbledore-HP-1-2](https://huggingface.co/Loren85/Albus-Dumbledore-HP-1-2)
- **斯内普**: [jackisyi/Severussnape](https://huggingface.co/jackisyi/Severussnape)

## 注意事项

- GitHub Actions使用CPU运行，速度较慢
- 如果模型下载失败，会自动使用简化版处理
- 建议将模型文件直接放入仓库以避免下载问题
