% Reconstruire une surface via l'algorithme de Multi-View Stereo (ou MVS).
% Utilisé par lancement_test.m

function [z_estime,erreur_z,espace_z_suivant,n_totales_ind] = mvs(premiere_iteration,surface,nb_vues,rayon_voisinage,sigma_filtre_I,nb_z,z_precedent,espace_z,utilisation_profondeurs_GT,grille_pixels)

	%% Paramètres
	interpolation 	= 'linear';			% Type d'interpolation utilisée
	estimateur		= 'MSE';			% Estimateur utilisé pour l'évaluation des erreurs photométriques
	affichage 		= 'Iteration';		% Type d'affichage de la progression de l'algorithme
	offset 			= 0.5;				% Décalage spatial entre les indices des pixels et leur coordonnées


	%% Données
	% Chargement des fonctions utiles
	addpath(genpath("../toolbox/"));
	% Chargement des données
	path = "../../data/perspectif/";
	nom_fichier = "simulateur_" + surface + "_formate.mat";
	load(path+nom_fichier);
	clear N;
	% Nombres d'images et de pixels considérés
	nb_pixels = nb_lignes * nb_colonnes;
	nb_images = nb_vues;
	taille_patch  = (2*rayon_voisinage + 1)^2;		% Nombre de pixels dans un patch
	% Les profondeurs
	Z_VT = z(:,:,1);
	clear z;
	if (premiere_iteration)
		if (surface == "plan_bis")
			valeurs_z = linspace(4,6,nb_z);
		else
			valeurs_z = linspace(min(Z_VT,[],'all'),max(Z_VT,[],'all'),nb_z);
		end
	else
		valeurs_z = linspace(-espace_z,espace_z,nb_z);	% Valeurs de profondeurs testées
	end
	if (utilisation_profondeurs_GT)
		nb_z = 1;
	end
	% Les poses relatives des caméras
	R_1_k = zeros(3,3,nb_images-1);
	t_1_k = zeros(3,nb_images-1);
	for k = 1:nb_images-1
		R_1_k(:,:,k) = R(:,:,k+1) * R(:,:,1)';
		t_1_k(:,k) = t(:,k+1) - R_1_k(:,:,k) * t(:,1);
	end
	% La matrice inverse de calibrage
	%K_inv = inv(K);
	if exist('K')
		K_inv = inv(K);
		K = repmat(K,1,1,nb_images);
	end
	if exist('K_multi')
		K = K_multi;
		K_inv = inv(K(:,:,1));
	end
	% Modifications du masque (pour correspondre aux patchs utilisés)
	masque(1:rayon_voisinage,:,1) = 0;
	masque(end-rayon_voisinage:end,:,1) = 0;
	masque(:,1:rayon_voisinage,1) = 0;
	masque(:,end-rayon_voisinage:end,1) = 0;
	% Filtrage des pixels considérés par le masque
	[i_k, j_k]  = find(masque(:,:,1));
	ind_1		= sub2ind([nb_lignes nb_colonnes], i_k, j_k);
	clear masque;
	% Utilisation d'une grille régulière de pixels
	if (grille_pixels > 0)
		indices_grilles = (mod(i_k,grille_pixels) == 1) & (mod(j_k,grille_pixels) == 1);
		ind_1 = ind_1(find(indices_grilles));
		i_k = i_k(find(indices_grilles));
		j_k = j_k(find(indices_grilles));
	end
	nb_pixels_etudies = size(ind_1,1);
	P_k 		= zeros(3,nb_pixels_etudies,nb_images);
	u_k 		= zeros(nb_pixels_etudies,nb_images);
	v_k 		= zeros(nb_pixels_etudies,nb_images);
	u_k(:,1)	= j_k - offset;
	v_k(:,1)	= i_k - offset;
	p_1			= [u_k(:,1) , v_k(:,1) , ones(nb_pixels_etudies,1)]';
	if (premiere_iteration)
		z_grossiers_estimes = zeros(nb_pixels_etudies,1);
	else
		z_grossiers_estimes = z_precedent(ind_1);
	end


	%% Calcul du filtre
	if (sigma_filtre_I > 0)
		cote_masque_I = ceil(4*sigma_filtre_I);
		filtre_I = fspecial('gauss',cote_masque_I,sigma_filtre_I);
		filtre_I = filtre_I / sum(filtre_I(:));
		I_filtre = zeros(size(I));
		for k = 1:nb_images
			I_filtre(:,:,k) = conv2(I(:,:,k),filtre_I,'same');
		end
	else
		I_filtre = I;
	end
	clear I;

	%% Construction du voisinage
	voisinage_ligne = -rayon_voisinage*nb_lignes:nb_lignes:rayon_voisinage*nb_lignes;
	voisinage_colonne = -rayon_voisinage:rayon_voisinage;
	grille_voisinage = voisinage_ligne + voisinage_colonne';
	grille_voisinage = grille_voisinage';

	%% Boucle de reconstruction
	erreurs	= 10*ones(nb_pixels_etudies, nb_z);
	n_estimes = zeros(3, nb_pixels_etudies, nb_z);

	tic
	for indice_z = 1:nb_z

		% Affichage de la progression des calculs
		switch (affichage)
			case 'Iteration'
				fprintf('\r');
				fprintf("Progression : %d / %d",indice_z,nb_z);
			case 'Pourcentage'
				if mod(indice_z,round(nb_z/25)) == 0
					disp("Progression à " + int2str(indice_z/nb_z*100) + "%");
				end
		end

		% Sélection d'une profondeur
		%tic
		valeur_z 	= z_grossiers_estimes + valeurs_z(indice_z);
		if (utilisation_profondeurs_GT)
			Z = repmat(Z_VT(ind_1)',3,1);
		else
			Z = repmat(valeur_z',3,1);
		end
		P_k(:,:,1) = Z .* (K_inv * p_1);
		%toc

		% Changements de repère
		%tic
		for k = 1:nb_images-1
			P_k(:,:,k+1) = R_1_k(:,:,k) * P_k(:,:,1) + t_1_k(:,k);
			p_k = (K(:,:,k+1) * P_k(:,:,k+1)) ./ P_k(3,:,k+1);
			u_k(:,k+1) = p_k(1,:)';
			v_k(:,k+1) = p_k(2,:)';
			i_k(:,k+1) = v_k(:,k+1) + offset;
			j_k(:,k+1) = u_k(:,k+1) + offset;
		end
		%toc

		% Vérification des pixels hors images
		%tic
		condition_image = ones(nb_pixels_etudies,nb_images-1);
		for k = 1:nb_images-1
			condition_image(:,k) = i_k(:,k+1) > 0.5 & i_k(:,k+1) <= nb_lignes & j_k(:,k+1) > 0.5 & j_k(:,k+1) <= nb_colonnes;
		end
		%toc

		% Les normales fronto-parallèles
		normale = zeros(3,nb_pixels_etudies);
		normale(3,:) = -1;
		n_estimes(:,:,indice_z) = normale;

		% Calcul du plan considéré
		d_equation_plan = sum(-P_k(:,:,1) .* normale,1);

		% Calcul de la transformation géométrique
		ind_decales = ind_1 + grille_voisinage(:)'; % Création de matrice avec 2 vecteurs
		[i_1_decales, j_1_decales] = ind2sub([nb_lignes, nb_colonnes], ind_decales);
		u_1_decales = j_1_decales - offset;
		v_1_decales = i_1_decales - offset;
		clear ind_decales;

		% Reprojection du voisinage
		%{
		i_k_voisinage = zeros(nb_pixels_etudies, taille_patch, nb_images-1);
		j_k_voisinage = zeros(nb_pixels_etudies, taille_patch, nb_images-1);
		u_1_decales_vec = reshape(u_1_decales',1,nb_pixels_etudies*taille_patch);
		v_1_decales_vec = reshape(v_1_decales',1,nb_pixels_etudies*taille_patch);
		for k = 1:nb_images-1
			for pixel = 1:nb_pixels_etudies
				homographie = K * (R_1_k(:,:,k) - t_1_k(:,k) * normale(:,pixel)' / d_equation_plan(pixel)) * K_inv;	
				p_k_voisinage = homographie * Z(1,pixel) * [u_1_decales(pixel,:) ; v_1_decales(pixel,:) ; ones(1,taille_patch)];
				u_k_voisinage = p_k_voisinage(1,:) ./ p_k_voisinage(3,:);
				v_k_voisinage = p_k_voisinage(2,:) ./ p_k_voisinage(3,:);
				i_k_voisinage(pixel,:,k) = v_k_voisinage + offset;
				j_k_voisinage(pixel,:,k) = u_k_voisinage + offset;
			end
		end
		%}
		i_k_voisinage = zeros(nb_pixels_etudies, taille_patch, nb_images-1);
		j_k_voisinage = zeros(nb_pixels_etudies, taille_patch, nb_images-1);
		u_1_decales_vec = reshape(u_1_decales',1,taille_patch,nb_pixels_etudies);
		v_1_decales_vec = reshape(v_1_decales',1,taille_patch,nb_pixels_etudies);
		p_1_vec = [u_1_decales_vec ; v_1_decales_vec ; ones(1,taille_patch,nb_pixels_etudies)];
		clear u_1_decales v_1_decales u_1_decales_vec v_1_decales_vec;
		for k = 1:nb_images-1
			homographie_totale = pagemtimes(K(:,:,k+1),pagemtimes(R_1_k(:,:,k) - pagemtimes(t_1_k(:,k),reshape((normale./d_equation_plan),1,3,nb_pixels_etudies)),K_inv));
			p_k_voisinage = pagemtimes(homographie_totale, pagemtimes(reshape(Z(1,:),1,1,nb_pixels_etudies), p_1_vec));
			u_k_voisinage = permute(p_k_voisinage(1,:,:) ./ p_k_voisinage(3,:,:),[3 2 1]);
			v_k_voisinage = permute(p_k_voisinage(2,:,:) ./ p_k_voisinage(3,:,:),[3 2 1]);
			i_k_voisinage(:,:,k) = v_k_voisinage + offset;
			j_k_voisinage(:,:,k) = u_k_voisinage + offset;
		end
		clear u_k_voisinage v_k_voisinage d_equation_plan;

		% Calcul de l'erreur
		%tic
		I_1_voisinage = interp2(I_filtre(:,:,1),j_1_decales,i_1_decales,interpolation);
		erreur_k = zeros(nb_pixels_etudies, nb_images-1);
		for k = 1:nb_images-1
			I_k_voisinage = interp2(I_filtre(:,:,k+1),j_k_voisinage(:,:,k),i_k_voisinage(:,:,k),interpolation);
			erreur_k(:,k) = condition_image(:,k).*sum((I_1_voisinage-I_k_voisinage),2);
		end
		switch (estimateur)
			case 'MSE'
				erreurs(:,indice_z) = (1 ./ sum(condition_image,2)) .* sum(erreur_k.^2,2);
			case 'Robuste'
				erreurs(:,indice_z) = (1 ./ sum(condition_image,2)) .* (1 - exp(-sum(erreur_k.^2,2)/0.2^2));
		end
		%toc

	end

	fprintf('\n');
	toc

	%% Résultats

	% Sélections des profondeurs avec l'erreur minimale
	erreurs_corrigees = erreurs;
	[~,indices_min] = min(erreurs_corrigees,[],2);
	if (utilisation_profondeurs_GT)
		z_in = Z_VT(ind_1);
	else
		z_in = z_grossiers_estimes + transpose(valeurs_z(indices_min));
	end
	z_estime = nan(nb_lignes, nb_colonnes);
	z_estime(ind_1) = z_in;

	% Calcul des erreurs de reconstruction
	Z_1_in = Z_VT(ind_1);
	erreur_z = abs(Z_1_in - z_in);

	% Sélection des normales
	n_totales = zeros(3, nb_pixels);
	n_totales_ind = zeros(3, nb_pixels_etudies);
	for k = 1:3
		n_totales(k,ind_1) = n_estimes(sub2ind(size(n_estimes), k * ones(nb_pixels_etudies,1), transpose(1:nb_pixels_etudies), indices_min));
		n_totales_ind(k,:) = n_totales(k,ind_1);
	end

	% Sauvegarde de la zone de recherche
	if (utilisation_profondeurs_GT)
		espace_z_suivant = 0;
	else
		espace_z_suivant = abs(valeurs_z(2) - valeurs_z(1));
	end

end
