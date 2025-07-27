#pragma once

#include "Common/GraphicsContext.h"
#include "Common/GPU/thin3d.h"

class DummyGraphicsContext : public GraphicsContext {
public:
    DummyGraphicsContext() = default;
    ~DummyGraphicsContext() override = default;

    // Required pure virtual methods
    void Shutdown() override {}
    void Resize() override {}

    Draw::DrawContext *GetDrawContext() override {
        return nullptr;
    }

    // Optional virtuals — override if necessary
    bool InitFromRenderThread(std::string *errorMessage) override {
        if (errorMessage) *errorMessage = "";
        return true;
    }

    void ShutdownFromRenderThread() override {}

    void ThreadStart() override {}
    bool ThreadFrame() override { return true; }
    void ThreadEnd() override {}
    void StopThread() override {}

    void Pause() override {}
    void Resume() override {}

    void *GetAPIContext() override { return nullptr; }

    void Poll() override {}
};
