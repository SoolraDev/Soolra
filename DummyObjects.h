#pragma once
#include "Common/GPU/thin3d.h"

class DummyInputLayout : public Draw::InputLayout {
public:
    void Release()  { delete this; }
};

class DummyDepthStencilState : public Draw::DepthStencilState {
public:
    void Release()  { delete this; }
};

class DummyBlendState : public Draw::BlendState {
public:
    void Release()  { delete this; }
};

class DummyRasterState : public Draw::RasterState {
public:
    void Release()  { delete this; }
};

class DummyPipeline : public Draw::Pipeline {
public:
    void Release()  { delete this; }
};
class DummyBuffer : public Draw::Buffer {
public:
    void Release()  { delete this; }
};

class DummyTexture : public Draw::Texture {
public:
    void Release()  { delete this; }
};

class DummyFramebuffer : public Draw::Framebuffer {
public:
    void Release()  { delete this; }
};
