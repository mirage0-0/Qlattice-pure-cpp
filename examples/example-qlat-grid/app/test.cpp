#include <qlat-grid/qlat-grid.h>
#include <qlat/qlat.h>
#include <iostream>

int main(int argc, char** argv)
{
    using namespace qlat;
    
    std::cout << "=== Qlat-Grid Example Test ===" << std::endl;
    
    std::vector<Coordinate> node_size_list;
    node_size_list.push_back(Coordinate(2, 2, 2, 4));
    
    begin_with_grid({}, node_size_list);
    
    std::cout << "Grid initialized successfully." << std::endl;
    
    const Coordinate total_site(4, 4, 4, 8);
    Geometry geo;
    geo.init(total_site);
    
    std::cout << "Geometry initialized: " << total_site[0] << "x" << total_site[1] 
              << "x" << total_site[2] << "x" << total_site[3] << std::endl;
    
    GaugeField gf;
    gf.init(geo);
    set_unit(gf);
    
    std::cout << "Gauge field initialized and set to unit." << std::endl;
    
    gf_show_info(gf);
    
    end_with_grid();
    
    std::cout << "CHECK: finished successfully." << std::endl;
    
    return 0;
}
