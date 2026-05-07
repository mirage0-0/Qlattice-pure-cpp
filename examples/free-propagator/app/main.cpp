#include <qlat/qlat.h>
#include <iostream>
#include <iomanip>

int main(int argc, char** argv)
{
    using namespace qlat;
    
    // Initialize qlat
    begin(&argc, &argv);
    
    std::cout << "=== Free Propagator Example ===" << std::endl;
    
    // Lattice parameters
    const Coordinate total_site(16, 16, 16, 32);
    const Coordinate source_pos(0, 0, 0, 0);
    const Coordinate check_pos(4, 4, 4, 4);
    const RealD mass = 0.01;
    
    std::cout << "Lattice size: " << total_site[0] << "x" << total_site[1] 
              << "x" << total_site[2] << "x" << total_site[3] << std::endl;
    std::cout << "Quark mass: " << mass << std::endl;
    std::cout << "Source position: (" << source_pos[0] << "," << source_pos[1] 
              << "," << source_pos[2] << "," << source_pos[3] << ")" << std::endl;
    std::cout << "Check position: (" << check_pos[0] << "," << check_pos[1] 
              << "," << check_pos[2] << "," << check_pos[3] << ")" << std::endl;
    
    // Create geometry
    Geometry geo;
    geo.init(total_site);
    
    std::cout << "Geometry initialized." << std::endl;
    
    // Create propagator fields
    Propagator4d src, sol;
    src.init(geo);
    sol.init(geo);
    
    std::cout << "Propagator fields initialized." << std::endl;
    
    // Set point source at origin
    set_point_src(src, geo, source_pos, ComplexD(1.0, 0.0));
    
    std::cout << "Point source set at origin." << std::endl;
    
    // Solve free propagator
    free_invert(sol, src, mass);
    
    std::cout << "Free propagator solved." << std::endl;
    
    // Extract Wilson matrix at coordinate (4,4,4,4)
    // First convert global coordinate to local coordinate
    const Coordinate xl = geo.coordinate_l_from_g(check_pos);
    
    if (geo.is_local(check_pos)) {
        const WilsonMatrix& wm = sol.get_elem(xl);
        
        std::cout << "\nWilson matrix at (" << check_pos[0] << "," << check_pos[1] 
                  << "," << check_pos[2] << "," << check_pos[3] << "):" << std::endl;
        std::cout << "Local coordinate: (" << xl[0] << "," << xl[1] 
                  << "," << xl[2] << "," << xl[3] << ")" << std::endl;
        
        // Print 12x12 matrix with row/column headers
        std::cout << "\n         ";
        for (int j = 0; j < 12; ++j) {
            std::cout << std::setw(10) << ("c" + std::to_string(j));
        }
        std::cout << "\n";
        
        for (int i = 0; i < 12; ++i) {
            std::cout << "r" << std::setw(2) << i << "   ";
            for (int j = 0; j < 12; ++j) {
                const ComplexD& val = wm(i, j);
                std::cout << std::setw(10) << std::fixed << std::setprecision(4) 
                          << val.real() << (val.imag() >= 0 ? "+" : "") 
                          << val.imag() << "i";
            }
            std::cout << "\n";
        }
        
        std::cout << "\nTotal elements: 144 (12x12 matrix)" << std::endl;
    } else {
        std::cout << "Coordinate (" << check_pos[0] << "," << check_pos[1] 
                  << "," << check_pos[2] << "," << check_pos[3] 
                  << ") is not local to this node." << std::endl;
    }
    
    // Cleanup
    end();
    
    std::cout << "\n=== Example completed successfully ===" << std::endl;
    
    return 0;
}
