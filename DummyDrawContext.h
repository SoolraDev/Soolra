#pragma once

#include "Common/GPU/thin3d.h"
#include "DummyShaderModule.h"
#include "DummyObjects.h"

class DummyDrawContext : public Draw::DrawContext {
public:


DummyDrawContext() {
    // Safe defaults
    caps_.coordConvention = CoordConvention::OpenGL;

    shaderLanguageDesc_.shaderLanguage = ShaderLanguage::GLSL_1xx;
    shaderLanguageDesc_.glslVersionNumber = 100;
    std::strncpy(shaderLanguageDesc_.driverInfo, "Dummy", sizeof(shaderLanguageDesc_.driverInfo) - 1);

    // Dummy vertex/fragment shader preset population
    for (int i = 0; i < Draw::VS_MAX_PRESET; ++i) {
        vsPresets_[i] = new DummyShaderModule(ShaderStage::Vertex, ShaderLanguage::GLSL_1xx);
    }
    for (int i = 0; i < Draw::FS_MAX_PRESET; ++i) {
        fsPresets_[i] = new DummyShaderModule(ShaderStage::Fragment, ShaderLanguage::GLSL_1xx);
    }
}
    ~DummyDrawContext() override {
        for (int i = 0; i < Draw::VS_MAX_PRESET; ++i) {
            delete vsPresets_[i];
            vsPresets_[i] = nullptr;
        }
        for (int i = 0; i < Draw::FS_MAX_PRESET; ++i) {
            delete fsPresets_[i];
            fsPresets_[i] = nullptr;
        }
    }



    const Draw::DeviceCaps &GetDeviceCaps() const override { return caps_; }
    uint32_t GetDataFormatSupport(Draw::DataFormat fmt) const override { return 0; }

    Draw::ShaderModule *CreateShaderModule(ShaderStage, ShaderLanguage, const uint8_t *, size_t, const char *) override { return nullptr; }
    uint32_t GetSupportedShaderLanguages() const override { return (uint32_t)ShaderLanguage::GLSL_1xx; }

    Draw::DepthStencilState *CreateDepthStencilState(const Draw::DepthStencilStateDesc &) override {
        return new DummyDepthStencilState();
    }

    Draw::BlendState *CreateBlendState(const Draw::BlendStateDesc &) override {
        return new DummyBlendState();
    }
    Draw::SamplerState *CreateSamplerState(const Draw::SamplerStateDesc &) override { return nullptr; }
    Draw::RasterState *CreateRasterState(const Draw::RasterStateDesc &) override {
        return new DummyRasterState();
    }
    Draw::InputLayout *CreateInputLayout(const Draw::InputLayoutDesc &) override {
        return new DummyInputLayout();
    }
    Draw::Pipeline *CreateGraphicsPipeline(const Draw::PipelineDesc &, const char *) override {
        return new DummyPipeline();
    }
    Draw::Buffer *CreateBuffer(size_t, uint32_t) override {
        return new DummyBuffer();
    }

    Draw::Texture *CreateTexture(const Draw::TextureDesc &) override {
        return new DummyTexture();
    }

    Draw::Framebuffer *CreateFramebuffer(const Draw::FramebufferDesc &) override {
        return new DummyFramebuffer();
    }

    void UpdateBuffer(Draw::Buffer *, const uint8_t *, size_t, size_t, Draw::UpdateBufferFlags) override {}
    void UpdateTextureLevels(Draw::Texture *, const uint8_t **, Draw::TextureCallback, int) override {}
    void CopyFramebufferImage(
        Draw::Framebuffer *src, int level, int x, int y, int z,
        Draw::Framebuffer *dst, int dstLevel, int dstX, int dstY, int dstZ,
        int width, int height, int depth,
        Draw::Aspect aspects, const char *tag) override {}

    bool BlitFramebuffer(Draw::Framebuffer *, int, int, int, int, Draw::Framebuffer *, int, int, int, int, Draw::Aspect, Draw::FBBlitFilter, const char *) override { return false; }

    void BindFramebufferAsRenderTarget(Draw::Framebuffer *, const Draw::RenderPassInfo &, const char *) override {}
    void BindFramebufferAsTexture(Draw::Framebuffer *, int, Draw::Aspect, int) override {}
    void GetFramebufferDimensions(Draw::Framebuffer *, int *w, int *h) override { *w = 480; *h = 272; }

    void SetScissorRect(int, int, int, int) override {}
    void SetViewport(const Draw::Viewport &) override {}
    void SetBlendFactor(float[4]) override {}
    void SetStencilParams(uint8_t, uint8_t, uint8_t) override {}

    void BindSamplerStates(int, int, Draw::SamplerState **) override {}
    void BindTextures(int, int, Draw::Texture **, Draw::TextureBindFlags) override {}
    void BindVertexBuffer(Draw::Buffer *, int) override {}
    void BindIndexBuffer(Draw::Buffer *, int) override {}
    void BindNativeTexture(int, void *) override {}
    void UpdateDynamicUniformBuffer(const void *, size_t) override {}

    void Invalidate(InvalidationFlags) override {}
    void BindPipeline(Draw::Pipeline *) override {}

    void Draw(int, int) override {}
    void DrawIndexed(int, int) override {}
    void DrawUP(const void *, int) override {}
    void DrawIndexedUP(const void *, int, const void *, int) override {}
    void DrawIndexedClippedBatchUP(const void *, int, const void *, int, Slice<Draw::ClippedDraw>, const void *, size_t) override {}

    void BeginFrame(Draw::DebugFlags) override {}
    void EndFrame() override {}
    void Present(Draw::PresentMode, int) override {}
    void Clear(Draw::Aspect, uint32_t, float, int) override {}

    std::string GetInfoString(Draw::InfoField) const override { return "DummyDrawContext"; }
    uint64_t GetNativeObject(Draw::NativeObject, void *) override { return 0; }

    void HandleEvent(Draw::Event, int, int, void *, void *) override {}
    void SetInvalidationCallback(InvalidationCallback) override {}
    int GetFrameCount() override { return 0; }

private:
    Draw::DeviceCaps caps_{};
};
