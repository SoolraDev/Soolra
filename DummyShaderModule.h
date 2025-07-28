

#pragma once
#include "Common/GPU/thin3d.h"

class DummyShaderModule : public Draw::ShaderModule {
public:
    ShaderStage stage_;
    ShaderLanguage lang_;

    DummyShaderModule(ShaderStage stage, ShaderLanguage lang)
        : stage_(stage), lang_(lang) {}

    ~DummyShaderModule() override {}

    ShaderStage GetStage() const override { return stage_; }
};
