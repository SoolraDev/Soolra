//
//  SoolraSoundDriver.hpp
//  SOOLRA
//

#ifndef SoolraSoundDriver_hpp
#define SoolraSoundDriver_hpp

#include "core/base/sound_driver.h"
#include <cstdint>

class SoolraSoundDriver final : public SoundDriver {
public:
    // Constructor/Destructor
    SoolraSoundDriver();
    ~SoolraSoundDriver() override = default;
    
    // Delete copy and move operations
    SoolraSoundDriver(const SoolraSoundDriver&) = delete;
    SoolraSoundDriver& operator=(const SoolraSoundDriver&) = delete;
    SoolraSoundDriver(SoolraSoundDriver&&) = delete;
    SoolraSoundDriver& operator=(SoolraSoundDriver&&) = delete;
    
    // Sound driver interface implementation
    bool init(long sampleRate) override;
    void pause() override;
    void reset() override;
    void resume() override;
    void write(uint16_t* finalWave, int length) override;
    void setThrottle(unsigned short throttle) override;
    
private:
    long currentSampleRate;
    bool isInitialized;
    bool isPaused;
};

#endif /* SoolraSoundDriver_hpp */ 
