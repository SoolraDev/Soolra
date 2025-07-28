#pragma once

#include "Common/GraphicsContext.h"
#include "DummyDrawContext.h"
#include "Common/GPU/thin3d.h"

class DummyGraphicsContext : public GraphicsContext {
public:
    DummyGraphicsContext() {
            drawContext_ = new DummyDrawContext();
        }

        ~DummyGraphicsContext() {
            delete drawContext_;
        }

        Draw::DrawContext *GetDrawContext() override {
            return drawContext_;
        }

    // Required pure virtual methods
    void Shutdown() override {}
    void Resize() override {}

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
private:
    DummyDrawContext *drawContext_;
};
