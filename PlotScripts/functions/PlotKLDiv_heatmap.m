function [hImage, hText, hXText] = PlotKLDiv_heatmap(kldivs,subV_labels,trainNum_labels,nPerm)

    plot_title = strcat('KLDivergence RapidPT vs. SnPM - ',num2str(nPerm),' Permutations');
	[hImage, hText, hXText] = heatmap(kldivs,subV_labels,trainNum_labels,...
                                      '%0.2f','Colorbar',true,...
                                      'FontSize', 12,...
                                      'MinColorValue', 0,...
                                      'MaxColorValue', 0.25,...
                                      'GridLines',':',...
                                      'TextColor','w');
                                      
                                      
    title(plot_title,'fontweight','bold')
    xlabel('Sampling Rate');
    ylabel('Number of Training Samples');
    set(gca,'FontSize',14,'FontName','Arial')
    

end